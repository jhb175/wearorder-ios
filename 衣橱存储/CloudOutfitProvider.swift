import Foundation

/// Cloud-backed outfit generation. POSTs the candidate pool + user
/// prompt to our Go backend, which fans out to whatever LLM provider
/// the admin has configured (DeepSeek / 混元 / Moonshot / OpenRouter / …).
///
/// The wire shape mirrors `backend/outfit.go`. Keeping schema names
/// identical means the only thing that ever changes between client and
/// server is a single HTTP hop.
@MainActor
struct CloudOutfitProvider: AIOutfitProviding {

    var modelIdentifier: String { "wearorder-cloud" }

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 90
            cfg.timeoutIntervalForResource = 120
            cfg.waitsForConnectivity = false
            self.session = URLSession(configuration: cfg)
        }
    }

    // MARK: - Wire types

    private struct RequestBody: Encodable {
        let userPrompt: String
        let weatherSummary: String
        let candidates: [String: [Item]]

        enum CodingKeys: String, CodingKey {
            case userPrompt = "user_prompt"
            case weatherSummary = "weather_summary"
            case candidates
        }
    }

    private struct Item: Encodable {
        let id: String
        let name: String
        let color: String
        let season: String
        let styleTags: [String]
        let isFavorite: Bool

        enum CodingKeys: String, CodingKey {
            case id, name, color, season
            case styleTags = "style_tags"
            case isFavorite = "is_favorite"
        }
    }

    private struct ResponseBody: Decodable {
        let title: String
        let reason: String
        let topItemID: String?
        let bottomItemID: String?
        let outerwearItemID: String?
        let shoesItemID: String?
        let bagItemID: String?
        let accessoryItemID: String?
        let providerName: String
        let modelIdentifier: String

        enum CodingKeys: String, CodingKey {
            case title, reason
            case topItemID = "top_item_id"
            case bottomItemID = "bottom_item_id"
            case outerwearItemID = "outerwear_item_id"
            case shoesItemID = "shoes_item_id"
            case bagItemID = "bag_item_id"
            case accessoryItemID = "accessory_item_id"
            case providerName = "provider_name"
            case modelIdentifier = "model_identifier"
        }
    }

    private struct ErrorBody: Decodable {
        let error: String
    }

    // MARK: - Generation

    func generate(context: AIWardrobeContext) async throws -> AIOutfitGenerator.GenerationResult {
        guard let baseURL = BackendOutfitConfig.baseURL else {
            throw AIOutfitGenerator.GenerationError.unavailable(
                reason: "云端 AI 尚未配置。"
            )
        }

        let endpoint = baseURL.appendingPathComponent("v1/ai/generate-outfit")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(BackendOutfitConfig.deviceID, forHTTPHeaderField: "X-Device-ID")

        let body = RequestBody(
            userPrompt: context.userPrompt,
            weatherSummary: context.weatherSummary,
            candidates: serialize(context.candidatesBySlot)
        )
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AIOutfitGenerator.GenerationError.modelError(
                message: "请求体序列化失败：\(error.localizedDescription)"
            )
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIOutfitGenerator.GenerationError.modelError(
                message: "网络异常：\(error.localizedDescription)"
            )
        }

        guard let httpResp = response as? HTTPURLResponse else {
            throw AIOutfitGenerator.GenerationError.modelError(
                message: "服务器返回了非 HTTP 响应。"
            )
        }

        if httpResp.statusCode == 429 {
            let serverMessage = decodeErrorMessage(data) ?? "请求太频繁，请稍后再试。"
            throw AIOutfitGenerator.GenerationError.rateLimited(message: serverMessage)
        }

        if httpResp.statusCode == 400 {
            // Backend uses 400 both for client errors AND for the
            // friendly "off-topic" refusal. We don't have a typed
            // discriminator on the wire — distinguish by the message.
            let serverMessage = decodeErrorMessage(data) ?? "请求被拒绝。"
            if serverMessage.contains("我只能帮你搭配衣服") || serverMessage.contains("穿搭") {
                throw AIOutfitGenerator.GenerationError.offTopic(message: serverMessage)
            }
            throw AIOutfitGenerator.GenerationError.modelError(message: serverMessage)
        }

        guard (200...299).contains(httpResp.statusCode) else {
            let serverMessage = decodeErrorMessage(data) ?? "服务器返回 \(httpResp.statusCode)。"
            throw AIOutfitGenerator.GenerationError.modelError(message: serverMessage)
        }

        let decoded: ResponseBody
        do {
            decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            throw AIOutfitGenerator.GenerationError.invalidOutput(underlying: error)
        }

        let slotIDs: [String: String?] = [
            "top": decoded.topItemID,
            "bottom": decoded.bottomItemID,
            "outerwear": decoded.outerwearItemID,
            "shoes": decoded.shoesItemID,
            "bag": decoded.bagItemID,
            "accessory": decoded.accessoryItemID
        ]

        do {
            let resolved = try AIOutfitValidator.validate(
                title: decoded.title,
                reason: decoded.reason,
                slotIDs: slotIDs,
                context: context
            )
            return AIOutfitGenerator.GenerationResult(
                resolved: resolved,
                context: context,
                modelIdentifier: "cloud:\(decoded.modelIdentifier)",
                weatherSummary: context.weatherSummary,
                promptUsed: context.userPrompt
            )
        } catch {
            // Server-side validator should already have caught these,
            // but defend in depth — server admin could swap providers
            // and we don't want a misbehaving LLM to corrupt local data.
            throw AIOutfitGenerator.GenerationError.invalidOutput(underlying: error)
        }
    }

    // MARK: - Helpers

    private func serialize(_ pool: [String: [WardrobeItem]]) -> [String: [Item]] {
        var out: [String: [Item]] = [:]
        for (slot, items) in pool {
            out[slot] = items.map { item in
                Item(
                    id: item.id.uuidString.lowercased(),
                    name: item.name,
                    color: item.colorName,
                    season: item.season,
                    styleTags: Array(item.styleTags.prefix(3)),
                    isFavorite: item.isFavorite
                )
            }
        }
        return out
    }

    private func decodeErrorMessage(_ data: Data) -> String? {
        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data),
           !body.error.isEmpty {
            return body.error
        }
        // Some intermediaries (CDN error pages, etc.) return non-JSON.
        if let raw = String(data: data, encoding: .utf8) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.count < 200 {
                return trimmed
            }
        }
        return nil
    }
}
