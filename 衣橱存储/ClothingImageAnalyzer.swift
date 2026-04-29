import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreML)
import CoreML
#endif
#if canImport(Vision)
import Vision
#endif

struct ClothingImageColorSuggestion: Equatable, Sendable {
    let colorName: String
    let confidence: Double
    let red: Double
    let green: Double
    let blue: Double

    var confidencePercent: Int {
        Int((confidence * 100).rounded())
    }
}

struct ClothingImageClassificationLabel: Equatable, Sendable {
    let identifier: String
    let confidence: Double
}

struct ClothingImageCategorySuggestion: Equatable, Sendable {
    let category: WardrobeCategory
    let confidence: Double
    let matchedLabel: String

    var categoryName: String {
        category.rawValue
    }

    var confidencePercent: Int {
        Int((confidence * 100).rounded())
    }
}

enum ClothingImageAnalyzer {
    private nonisolated static let sampleDimension = 44

    #if canImport(UIKit)
    nonisolated static func suggestDominantColor(from data: Data) -> ClothingImageColorSuggestion? {
        guard let image = UIImage(data: data) else { return nil }
        return suggestDominantColor(from: image)
    }

    nonisolated static func suggestDominantColor(from image: UIImage) -> ClothingImageColorSuggestion? {
        guard let pixels = sampledPixels(from: image, dimension: sampleDimension) else { return nil }
        return dominantColorSuggestion(from: pixels)
    }
    #endif

    nonisolated static func suggestCategory(from data: Data) -> ClothingImageCategorySuggestion? {
        #if canImport(UIKit)
        let visualSuggestion = visualSilhouetteCategorySuggestion(from: data)
        #else
        let visualSuggestion: ClothingImageCategorySuggestion? = nil
        #endif

        #if canImport(UIKit) && canImport(CoreML)
        let labelSuggestion = customModelCategorySuggestion(from: data) ?? visionCategorySuggestion(from: data)
        #else
        let labelSuggestion = visionCategorySuggestion(from: data)
        #endif

        return reconciledCategorySuggestion(labelSuggestion: labelSuggestion, visualSuggestion: visualSuggestion)
    }

    nonisolated static func categorySuggestion(from labels: [ClothingImageClassificationLabel]) -> ClothingImageCategorySuggestion? {
        var scores: [WardrobeCategory: Double] = [:]
        var bestLabelByCategory: [WardrobeCategory: ClothingImageClassificationLabel] = [:]

        for label in labels where label.confidence >= 0.03 {
            let normalizedIdentifier = normalizedClassificationIdentifier(label.identifier)

            if let exactCategory = exactCategory(for: normalizedIdentifier) {
                addCategoryScore(
                    exactCategory,
                    label: label,
                    score: label.confidence * 1.35,
                    scores: &scores,
                    bestLabelByCategory: &bestLabelByCategory
                )
                continue
            }

            for rule in categoryRules where rule.matches(normalizedIdentifier) {
                addCategoryScore(
                    rule.category,
                    label: label,
                    score: label.confidence * rule.weight,
                    scores: &scores,
                    bestLabelByCategory: &bestLabelByCategory
                )
            }
        }

        guard let best = scores.max(by: { $0.value < $1.value }), best.value >= 0.10 else {
            return nil
        }

        let selectedCategory = categoryAdjustedForAccessoryNoise(
            bestCategory: best.key,
            bestScore: best.value,
            scores: scores
        )
        let selectedScore = scores[selectedCategory] ?? best.value
        let matchedLabel = bestLabelByCategory[selectedCategory]?.identifier ?? selectedCategory.rawValue
        return ClothingImageCategorySuggestion(
            category: selectedCategory,
            confidence: min(0.94, max(0.32, selectedScore)),
            matchedLabel: matchedLabel
        )
    }

    #if canImport(UIKit) && canImport(CoreML)
    private nonisolated static func customModelCategorySuggestion(from data: Data) -> ClothingImageCategorySuggestion? {
        guard
            let image = UIImage(data: data),
            let classifier = WearOrderClothingModelClassifier.shared,
            let labels = classifier.classificationLabels(for: image)
        else {
            return nil
        }

        return categorySuggestion(from: labels)
    }
    #endif

    private nonisolated static func visionCategorySuggestion(from data: Data) -> ClothingImageCategorySuggestion? {
        #if canImport(UIKit) && canImport(Vision)
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        let labels = (request.results ?? [])
            .prefix(10)
            .map {
                ClothingImageClassificationLabel(
                    identifier: $0.identifier,
                    confidence: Double($0.confidence)
                )
            }
        return categorySuggestion(from: labels)
        #else
        return nil
        #endif
    }

    private nonisolated static func reconciledCategorySuggestion(
        labelSuggestion: ClothingImageCategorySuggestion?,
        visualSuggestion: ClothingImageCategorySuggestion?
    ) -> ClothingImageCategorySuggestion? {
        guard let labelSuggestion else { return visualSuggestion }
        guard let visualSuggestion else { return labelSuggestion }

        if labelSuggestion.category == visualSuggestion.category {
            return ClothingImageCategorySuggestion(
                category: labelSuggestion.category,
                confidence: min(0.96, max(labelSuggestion.confidence, visualSuggestion.confidence) + 0.04),
                matchedLabel: labelSuggestion.matchedLabel
            )
        }

        if visualSuggestion.category == .dress,
           canDressVisualOverride(labelCategory: labelSuggestion.category),
           labelSuggestion.confidence < 0.88 {
            return visualSuggestion
        }

        if visualSuggestion.category == .skirt,
           canSkirtVisualOverride(labelCategory: labelSuggestion.category),
           labelSuggestion.confidence < 0.82 {
            return visualSuggestion
        }

        if visualSuggestion.category == .bottom,
           canBottomVisualOverride(labelCategory: labelSuggestion.category),
           labelSuggestion.confidence < 0.82 {
            return visualSuggestion
        }

        if visualSuggestion.category == .shoes,
           canShoesVisualOverride(labelCategory: labelSuggestion.category),
           labelSuggestion.confidence < 0.74 {
            return visualSuggestion
        }

        if isAccessoryGroup(labelSuggestion.category),
           isMainClothingGroup(visualSuggestion.category),
           labelSuggestion.confidence < 0.92 {
            return visualSuggestion
        }

        return labelSuggestion
    }

    nonisolated static func closestPaletteColorName(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        let hsb = hsb(red: red, green: green, blue: blue)
        let hue = hsb.hue * 360

        if hsb.brightness <= 0.14 {
            return "曜石黑"
        }

        if hsb.saturation <= 0.12 {
            if hsb.brightness >= 0.90 {
                if blue > red + 0.03 {
                    return "珠光白"
                }
                if red > blue + 0.04 {
                    return "暖白"
                }
                return "奶油白"
            }
            if hsb.brightness <= 0.58 {
                return "炭灰"
            }
            return "浅灰"
        }

        switch hue {
        case 0..<14, 345...360:
            if hsb.brightness < 0.55 || red > green * 1.45 {
                return "酒红"
            }
            return "玫瑰粉"
        case 14..<42:
            if hsb.brightness < 0.70 || hsb.saturation > 0.48 {
                return "焦糖棕"
            }
            return "燕麦卡其"
        case 42..<72:
            return "燕麦卡其"
        case 72..<165:
            return hsb.brightness < 0.50 ? "森林绿" : "鼠尾草绿"
        case 165..<250:
            return hsb.brightness < 0.58 && hsb.saturation > 0.42 ? "海军蓝" : "雾蓝"
        case 250..<292:
            return "丁香紫"
        case 292..<345:
            return hsb.brightness < 0.58 ? "酒红" : "玫瑰粉"
        default:
            return "奶油白"
        }
    }

    private nonisolated static func dominantColorSuggestion(from pixels: [SampledPixel]) -> ClothingImageColorSuggestion? {
        guard !pixels.isEmpty else { return nil }

        let foregroundPixels = pixels.filter { !$0.looksLikeBrightBackground }
        let candidatePixels = foregroundPixels.count >= pixels.count / 10 ? foregroundPixels : pixels
        var buckets: [String: ColorBucket] = [:]
        var totalWeight: Double = 0

        for pixel in candidatePixels {
            let colorName = closestPaletteColorName(red: pixel.red, green: pixel.green, blue: pixel.blue)
            let weight = pixel.analysisWeight
            totalWeight += weight
            buckets[colorName, default: ColorBucket()].add(pixel: pixel, weight: weight)
        }

        guard totalWeight > 0, let best = buckets.max(by: { $0.value.weight < $1.value.weight }) else {
            return nil
        }

        let average = best.value.averageRGB
        let confidence = min(0.96, max(0.35, best.value.weight / totalWeight))
        return ClothingImageColorSuggestion(
            colorName: best.key,
            confidence: confidence,
            red: average.red,
            green: average.green,
            blue: average.blue
        )
    }

    private nonisolated static func hsb(red: CGFloat, green: CGFloat, blue: CGFloat) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue

        let brightness = maxValue
        let saturation = maxValue == 0 ? 0 : delta / maxValue
        let hue: CGFloat

        if delta == 0 {
            hue = 0
        } else if maxValue == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6) / 6
        } else if maxValue == green {
            hue = (((blue - red) / delta) + 2) / 6
        } else {
            hue = (((red - green) / delta) + 4) / 6
        }

        return (hue < 0 ? hue + 1 : hue, saturation, brightness)
    }

    private nonisolated static func normalizedClassificationIdentifier(_ identifier: String) -> String {
        identifier
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func exactCategory(for identifier: String) -> WardrobeCategory? {
        switch identifier {
        case WardrobeCategory.top.rawValue, "top", "upper", "upper body", "tops":
            return .top
        case WardrobeCategory.tshirt.rawValue.lowercased(), "t shirt", "tshirt", "tee":
            return .tshirt
        case WardrobeCategory.shirt.rawValue, "shirt", "shirts":
            return .shirt
        case WardrobeCategory.blouse.rawValue, "blouse", "blouses":
            return .blouse
        case WardrobeCategory.knitwear.rawValue, "knitwear", "knit top":
            return .knitwear
        case WardrobeCategory.sweater.rawValue, "sweater", "jumper":
            return .sweater
        case WardrobeCategory.hoodie.rawValue, "hoodie", "sweatshirt":
            return .hoodie
        case WardrobeCategory.camisole.rawValue, "camisole", "tank top":
            return .camisole
        case WardrobeCategory.polo.rawValue.lowercased(), "polo", "polo shirt":
            return .polo
        case WardrobeCategory.outerwear.rawValue, "outerwear", "outer wear", "coat jacket":
            return .outerwear
        case WardrobeCategory.jacket.rawValue, "jacket":
            return .jacket
        case WardrobeCategory.blazer.rawValue, "blazer":
            return .blazer
        case WardrobeCategory.cardigan.rawValue, "cardigan":
            return .cardigan
        case WardrobeCategory.trenchCoat.rawValue, "trench coat":
            return .trenchCoat
        case WardrobeCategory.coat.rawValue, "coat", "overcoat":
            return .coat
        case WardrobeCategory.downJacket.rawValue, "down jacket", "puffer jacket":
            return .downJacket
        case WardrobeCategory.leatherJacket.rawValue, "leather jacket":
            return .leatherJacket
        case WardrobeCategory.vest.rawValue, "vest":
            return .vest
        case WardrobeCategory.bottom.rawValue, "bottom", "bottoms", "pants bottom", "lower body":
            return .bottom
        case WardrobeCategory.jeans.rawValue, "jeans", "denim jeans":
            return .jeans
        case WardrobeCategory.casualPants.rawValue, "casual pants":
            return .casualPants
        case WardrobeCategory.suitPants.rawValue, "suit pants", "dress pants", "slacks":
            return .suitPants
        case WardrobeCategory.shorts.rawValue, "shorts":
            return .shorts
        case WardrobeCategory.sportsPants.rawValue, "sports pants", "sweatpants", "joggers":
            return .sportsPants
        case WardrobeCategory.cargoPants.rawValue, "cargo pants":
            return .cargoPants
        case WardrobeCategory.leggings.rawValue, "leggings", "yoga pants":
            return .leggings
        case WardrobeCategory.skirt.rawValue, "skirt", "skirts", "dress skirt":
            return .skirt
        case WardrobeCategory.pleatedSkirt.rawValue, "pleated skirt":
            return .pleatedSkirt
        case WardrobeCategory.miniSkirt.rawValue, "mini skirt", "miniskirt":
            return .miniSkirt
        case WardrobeCategory.dress.rawValue, "dress", "dresses", "one piece", "onepiece":
            return .dress
        case WardrobeCategory.gown.rawValue, "evening dress", "formal dress", "gown":
            return .gown
        case WardrobeCategory.qipao.rawValue, "qipao", "cheongsam":
            return .qipao
        case WardrobeCategory.set.rawValue, "set", "sets", "suit set", "matching set":
            return .set
        case WardrobeCategory.jumpsuit.rawValue, "jumpsuit", "romper", "overall", "overalls":
            return .jumpsuit
        case WardrobeCategory.sportswear.rawValue, "sportswear", "activewear", "tracksuit":
            return .sportswear
        case WardrobeCategory.swimwear.rawValue, "swimwear", "swimsuit", "bikini":
            return .swimwear
        case WardrobeCategory.shoes.rawValue, "shoes", "shoe", "footwear":
            return .shoes
        case WardrobeCategory.sneakers.rawValue, "sneaker", "sneakers", "running shoe":
            return .sneakers
        case WardrobeCategory.casualShoes.rawValue, "casual shoes":
            return .casualShoes
        case WardrobeCategory.boots.rawValue, "boot", "boots":
            return .boots
        case WardrobeCategory.sandals.rawValue, "sandal", "sandals":
            return .sandals
        case WardrobeCategory.heels.rawValue, "heel", "heels", "pump":
            return .heels
        case WardrobeCategory.slippers.rawValue, "slipper", "slippers", "flip flop":
            return .slippers
        case WardrobeCategory.loafers.rawValue, "loafer", "loafers":
            return .loafers
        case WardrobeCategory.bag.rawValue, "bag", "bags", "handbag", "purse":
            return .bag
        case WardrobeCategory.toteBag.rawValue, "tote", "tote bag":
            return .toteBag
        case WardrobeCategory.shoulderBag.rawValue, "shoulder bag", "crossbody bag":
            return .shoulderBag
        case WardrobeCategory.backpack.rawValue, "backpack":
            return .backpack
        case WardrobeCategory.clutch.rawValue, "clutch":
            return .clutch
        case WardrobeCategory.wallet.rawValue, "wallet", "card holder":
            return .wallet
        case WardrobeCategory.luggage.rawValue, "luggage", "suitcase":
            return .luggage
        case WardrobeCategory.accessory.rawValue, "accessory", "accessories":
            return .accessory
        case WardrobeCategory.hat.rawValue, "hat", "hats", "cap":
            return .hat
        case WardrobeCategory.scarf.rawValue, "scarf", "shawl":
            return .scarf
        case WardrobeCategory.belt.rawValue, "belt":
            return .belt
        case WardrobeCategory.jewelry.rawValue, "jewelry", "jewellery":
            return .jewelry
        case WardrobeCategory.earrings.rawValue, "earring", "earrings":
            return .earrings
        case WardrobeCategory.necklace.rawValue, "necklace":
            return .necklace
        case WardrobeCategory.braceletRing.rawValue, "bracelet", "ring":
            return .braceletRing
        case WardrobeCategory.watch.rawValue, "watch":
            return .watch
        case WardrobeCategory.eyewear.rawValue, "glasses", "sunglasses", "eyewear":
            return .eyewear
        case WardrobeCategory.hairAccessory.rawValue, "hair accessory", "headband":
            return .hairAccessory
        case WardrobeCategory.socks.rawValue, "socks", "stockings":
            return .socks
        case WardrobeCategory.tie.rawValue, "tie", "bow tie":
            return .tie
        case WardrobeCategory.loungewear.rawValue, "loungewear":
            return .loungewear
        case WardrobeCategory.underwear.rawValue, "underwear", "bra", "lingerie":
            return .underwear
        case WardrobeCategory.pajamas.rawValue, "pajama", "pyjama", "sleepwear":
            return .pajamas
        case WardrobeCategory.kids.rawValue, "kids", "kid", "children", "child", "baby":
            return .kids
        case WardrobeCategory.pet.rawValue, "pet", "pet clothing", "dog clothing", "cat clothing":
            return .pet
        case WardrobeCategory.other.rawValue, "other":
            return .other
        default:
            return nil
        }
    }

    private nonisolated static func addCategoryScore(
        _ category: WardrobeCategory,
        label: ClothingImageClassificationLabel,
        score: Double,
        scores: inout [WardrobeCategory: Double],
        bestLabelByCategory: inout [WardrobeCategory: ClothingImageClassificationLabel]
    ) {
        scores[category, default: 0] += score

        let currentBest = bestLabelByCategory[category]?.confidence ?? 0
        if label.confidence > currentBest {
            bestLabelByCategory[category] = label
        }
    }

    private nonisolated static func categoryAdjustedForAccessoryNoise(
        bestCategory: WardrobeCategory,
        bestScore: Double,
        scores: [WardrobeCategory: Double]
    ) -> WardrobeCategory {
        guard isAccessoryGroup(bestCategory) else { return bestCategory }

        guard let clothingAlternative = scores
            .filter({ isClothingOrShoesGroup($0.key) })
            .max(by: { $0.value < $1.value }),
              clothingAlternative.value >= bestScore * 0.65 else {
            return bestCategory
        }

        return clothingAlternative.key
    }

    private nonisolated static func isAccessoryGroup(_ category: WardrobeCategory) -> Bool {
        if case .accessory = category.functionalGroup {
            return true
        }
        return false
    }

    private nonisolated static func isMainClothingGroup(_ category: WardrobeCategory) -> Bool {
        switch category.functionalGroup {
        case .top, .outerwear, .lowerBody, .onePiece:
            return true
        default:
            return false
        }
    }

    private nonisolated static func isClothingOrShoesGroup(_ category: WardrobeCategory) -> Bool {
        switch category.functionalGroup {
        case .top, .outerwear, .lowerBody, .onePiece, .shoes:
            return true
        default:
            return false
        }
    }

    private nonisolated static func canDressVisualOverride(labelCategory: WardrobeCategory) -> Bool {
        switch labelCategory.functionalGroup {
        case .top, .lowerBody, .accessory, .other:
            return true
        default:
            return false
        }
    }

    private nonisolated static func canSkirtVisualOverride(labelCategory: WardrobeCategory) -> Bool {
        switch labelCategory.functionalGroup {
        case .top, .lowerBody, .onePiece, .accessory, .other:
            return true
        default:
            return false
        }
    }

    private nonisolated static func canBottomVisualOverride(labelCategory: WardrobeCategory) -> Bool {
        switch labelCategory.functionalGroup {
        case .shoes, .accessory, .top, .other:
            return true
        default:
            return false
        }
    }

    private nonisolated static func canShoesVisualOverride(labelCategory: WardrobeCategory) -> Bool {
        switch labelCategory.functionalGroup {
        case .lowerBody, .accessory, .other:
            return true
        default:
            return false
        }
    }

    private nonisolated static let categoryRules: [CategoryRule] = [
        .init(category: .sneakers, keywords: ["sneaker", "running shoe", "athletic shoe", "trainer"], weight: 1.42),
        .init(category: .boots, keywords: ["boot", "boots", "ankle boot"], weight: 1.38),
        .init(category: .sandals, keywords: ["sandal", "sandals"], weight: 1.34),
        .init(category: .heels, keywords: ["heel", "heels", "pump", "stiletto"], weight: 1.34),
        .init(category: .slippers, keywords: ["slipper", "slippers", "flip flop"], weight: 1.32),
        .init(category: .loafers, keywords: ["loafer", "loafers"], weight: 1.32),
        .init(category: .shoes, keywords: ["shoe", "shoes", "footwear", "cleat"], weight: 1.20),
        .init(category: .toteBag, keywords: ["tote", "tote bag"], weight: 1.36),
        .init(category: .shoulderBag, keywords: ["shoulder bag", "crossbody", "messenger bag"], weight: 1.34),
        .init(category: .backpack, keywords: ["backpack"], weight: 1.34),
        .init(category: .wallet, keywords: ["wallet", "card holder"], weight: 1.32),
        .init(category: .luggage, keywords: ["suitcase", "luggage"], weight: 1.30),
        .init(category: .clutch, keywords: ["clutch"], weight: 1.28),
        .init(category: .bag, keywords: ["handbag", "purse", "bag", "duffel"], weight: 1.18),
        .init(category: .hat, keywords: ["hat", "cap", "beanie", "beret", "fedora", "sun hat"], weight: 1.22),
        .init(category: .dress, keywords: ["dress", "dresses", "gown", "one piece dress", "onepiece dress", "sundress", "evening dress", "evening gown", "wedding gown", "cocktail dress", "pinafore dress", "jumper dress", "robe", "kimono"], weight: 1.48),
        .init(category: .gown, keywords: ["evening gown", "wedding gown", "formal dress"], weight: 1.50),
        .init(category: .qipao, keywords: ["qipao", "cheongsam"], weight: 1.44),
        .init(category: .pleatedSkirt, keywords: ["pleated skirt"], weight: 1.42),
        .init(category: .miniSkirt, keywords: ["mini skirt", "miniskirt"], weight: 1.40),
        .init(category: .skirt, keywords: ["skirt", "skirts", "long skirt", "midi skirt", "overskirt", "sarong"], weight: 1.28),
        .init(category: .kids, keywords: ["kids clothing", "children clothing", "child clothing", "baby clothing", "toddler clothing", "kids apparel"], weight: 1.26),
        .init(category: .pet, keywords: ["pet clothing", "dog clothing", "cat clothing", "pet apparel", "dog apparel", "cat apparel"], weight: 1.26),
        .init(category: .jumpsuit, keywords: ["jumpsuit", "romper", "overall", "overalls"], weight: 1.34),
        .init(category: .swimwear, keywords: ["swimwear", "swimsuit", "bikini"], weight: 1.28),
        .init(category: .sportswear, keywords: ["activewear", "sportswear", "tracksuit", "yoga set"], weight: 1.22),
        .init(category: .set, keywords: ["matching set", "two piece", "two piece set", "suit set", "co ord", "co ord set"], weight: 1.20),
        .init(category: .underwear, keywords: ["underwear", "bra", "lingerie"], weight: 1.24),
        .init(category: .pajamas, keywords: ["pajama", "pyjama", "sleepwear", "homewear"], weight: 1.22),
        .init(category: .loungewear, keywords: ["loungewear"], weight: 1.16),
        .init(category: .top, keywords: ["school uniform", "sailor uniform", "sailor blouse", "sailor shirt", "sailor collar", "uniform top", "jk uniform", "jk top", "school blouse"], weight: 1.42),
        .init(category: .earrings, keywords: ["earring", "earrings"], weight: 1.34),
        .init(category: .necklace, keywords: ["necklace"], weight: 1.32),
        .init(category: .braceletRing, keywords: ["bracelet", "ring"], weight: 1.30),
        .init(category: .watch, keywords: ["watch"], weight: 1.28),
        .init(category: .belt, keywords: ["belt"], weight: 1.24),
        .init(category: .scarf, keywords: ["scarf", "shawl"], weight: 1.24),
        .init(category: .eyewear, keywords: ["sunglasses", "glasses", "eyewear"], weight: 1.22),
        .init(category: .hairAccessory, keywords: ["hair clip", "headband", "hair accessory"], weight: 1.20),
        .init(category: .socks, keywords: ["socks", "stockings"], weight: 1.20),
        .init(category: .tie, keywords: ["tie", "bow tie"], weight: 1.18),
        .init(category: .jewelry, keywords: ["jewelry", "jewellery"], weight: 1.14),
        .init(category: .accessory, keywords: ["accessory", "accessories", "glove"], weight: 1.04),
        .init(category: .jeans, keywords: ["jeans", "denim jeans"], weight: 1.32),
        .init(category: .shorts, keywords: ["shorts"], weight: 1.28),
        .init(category: .suitPants, keywords: ["slacks", "dress pants", "suit pants"], weight: 1.26),
        .init(category: .sportsPants, keywords: ["jogger", "joggers", "sweatpants"], weight: 1.24),
        .init(category: .cargoPants, keywords: ["cargo pants"], weight: 1.24),
        .init(category: .leggings, keywords: ["leggings", "yoga pants"], weight: 1.22),
        .init(category: .bottom, keywords: ["pants", "trouser", "trousers", "wide leg pants"], weight: 1.12),
        .init(category: .downJacket, keywords: ["down jacket", "puffer jacket"], weight: 1.28),
        .init(category: .trenchCoat, keywords: ["trench coat"], weight: 1.26),
        .init(category: .leatherJacket, keywords: ["leather jacket"], weight: 1.24),
        .init(category: .blazer, keywords: ["blazer"], weight: 1.22),
        .init(category: .cardigan, keywords: ["cardigan"], weight: 1.20),
        .init(category: .coat, keywords: ["coat", "overcoat", "parka"], weight: 1.12),
        .init(category: .jacket, keywords: ["jacket", "windbreaker"], weight: 1.10),
        .init(category: .vest, keywords: ["vest"], weight: 1.08),
        .init(category: .outerwear, keywords: ["outerwear"], weight: 1.02),
        .init(category: .hoodie, keywords: ["hoodie", "sweatshirt"], weight: 1.18),
        .init(category: .sweater, keywords: ["sweater", "jumper", "pullover"], weight: 1.16),
        .init(category: .knitwear, keywords: ["knitwear", "knit top"], weight: 1.14),
        .init(category: .camisole, keywords: ["tank top", "camisole"], weight: 1.12),
        .init(category: .polo, keywords: ["polo"], weight: 1.10),
        .init(category: .tshirt, keywords: ["t shirt", "tshirt", "tee"], weight: 1.10),
        .init(category: .shirt, keywords: ["shirt"], weight: 1.06),
        .init(category: .blouse, keywords: ["blouse"], weight: 1.06),
        .init(category: .top, keywords: ["top", "jersey"], weight: 1.02),
        .init(category: .top, keywords: ["apparel", "clothing", "garment"], weight: 0.20)
    ]

    #if canImport(UIKit)
    private nonisolated static func visualSilhouetteCategorySuggestion(from data: Data) -> ClothingImageCategorySuggestion? {
        guard let image = UIImage(data: data),
              let profile = visualSilhouetteProfile(from: image)
        else {
            return nil
        }

        if profile.aspectRatio > 1.36, profile.boxHeightRatio < 0.50, profile.areaRatio > 0.030 {
            return ClothingImageCategorySuggestion(category: .shoes, confidence: 0.56, matchedLabel: "横向鞋履轮廓")
        }

        if profile.boxHeightRatio > 0.54,
           profile.aspectRatio < 0.92,
           profile.lowerCenterOccupancy < 0.13,
           profile.lowerSpanRatio >= profile.upperSpanRatio * 0.72 {
            return ClothingImageCategorySuggestion(category: .bottom, confidence: 0.58, matchedLabel: "双腿下装轮廓")
        }

        if profile.boxHeightRatio > 0.58,
           profile.aspectRatio < 0.98,
           profile.lowerSpanRatio > profile.upperSpanRatio * 1.18,
           profile.middleSpanRatio > profile.upperSpanRatio * 0.82,
           profile.lowerCenterOccupancy >= 0.13 {
            return ClothingImageCategorySuggestion(category: .dress, confidence: 0.62, matchedLabel: "一件式连衣裙轮廓")
        }

        if profile.boxHeightRatio > 0.38,
           profile.boxHeightRatio < 0.70,
           profile.aspectRatio < 1.10,
           profile.lowerSpanRatio > profile.upperSpanRatio * 1.28,
           profile.lowerCenterOccupancy >= 0.11 {
            return ClothingImageCategorySuggestion(category: .skirt, confidence: 0.56, matchedLabel: "裙摆轮廓")
        }

        if profile.boxHeightRatio > 0.36,
           profile.boxWidthRatio > 0.28,
           profile.areaRatio > 0.055,
           profile.upperSpanRatio >= 0.22,
           profile.lowerSpanRatio <= profile.upperSpanRatio * 1.22 {
            return ClothingImageCategorySuggestion(category: .top, confidence: 0.48, matchedLabel: "上衣轮廓")
        }

        return nil
    }

    private nonisolated static func visualSilhouetteProfile(from image: UIImage, dimension: Int = 72) -> VisualSilhouetteProfile? {
        let size = CGSize(width: dimension, height: dimension)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderedImage = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: aspectFitRect(imageSize: image.size, targetSize: size))
        }

        guard let cgImage = renderedImage.cgImage else { return nil }
        var rawData = [UInt8](repeating: 0, count: dimension * dimension * 4)
        guard let context = CGContext(
            data: &rawData,
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bytesPerRow: dimension * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dimension, height: dimension))

        let background = estimatedBackgroundColor(rawData: rawData, dimension: dimension)
        var foregroundPoints: [(x: Int, y: Int)] = []
        foregroundPoints.reserveCapacity(dimension * dimension / 3)

        for y in 0..<dimension {
            for x in 0..<dimension {
                let offset = (y * dimension + x) * 4
                let red = CGFloat(rawData[offset]) / 255
                let green = CGFloat(rawData[offset + 1]) / 255
                let blue = CGFloat(rawData[offset + 2]) / 255
                if isForegroundPixel(red: red, green: green, blue: blue, background: background) {
                    foregroundPoints.append((x, y))
                }
            }
        }

        guard foregroundPoints.count > dimension * dimension / 45 else { return nil }

        let minX = foregroundPoints.map(\.x).min() ?? 0
        let maxX = foregroundPoints.map(\.x).max() ?? 0
        let minY = foregroundPoints.map(\.y).min() ?? 0
        let maxY = foregroundPoints.map(\.y).max() ?? 0
        let boxWidth = max(1, maxX - minX + 1)
        let boxHeight = max(1, maxY - minY + 1)
        let boxWidthRatio = Double(boxWidth) / Double(dimension)
        let boxHeightRatio = Double(boxHeight) / Double(dimension)

        return VisualSilhouetteProfile(
            boxWidthRatio: boxWidthRatio,
            boxHeightRatio: boxHeightRatio,
            areaRatio: Double(foregroundPoints.count) / Double(dimension * dimension),
            upperSpanRatio: horizontalSpanRatio(
                points: foregroundPoints,
                minX: minX,
                maxX: maxX,
                minY: minY,
                boxHeight: boxHeight,
                startFraction: 0.12,
                endFraction: 0.34
            ),
            middleSpanRatio: horizontalSpanRatio(
                points: foregroundPoints,
                minX: minX,
                maxX: maxX,
                minY: minY,
                boxHeight: boxHeight,
                startFraction: 0.38,
                endFraction: 0.60
            ),
            lowerSpanRatio: horizontalSpanRatio(
                points: foregroundPoints,
                minX: minX,
                maxX: maxX,
                minY: minY,
                boxHeight: boxHeight,
                startFraction: 0.66,
                endFraction: 0.92
            ),
            lowerCenterOccupancy: lowerCenterOccupancy(
                points: foregroundPoints,
                minX: minX,
                maxX: maxX,
                minY: minY,
                boxHeight: boxHeight
            )
        )
    }

    private nonisolated static func estimatedBackgroundColor(rawData: [UInt8], dimension: Int) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let sampleRange = 0..<min(8, dimension)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var count: CGFloat = 0

        for y in sampleRange {
            for x in sampleRange {
                let mirroredX = dimension - 1 - x
                let mirroredY = dimension - 1 - y
                for point in [(x, y), (mirroredX, y), (x, mirroredY), (mirroredX, mirroredY)] {
                    let offset = (point.1 * dimension + point.0) * 4
                    red += CGFloat(rawData[offset]) / 255
                    green += CGFloat(rawData[offset + 1]) / 255
                    blue += CGFloat(rawData[offset + 2]) / 255
                    count += 1
                }
            }
        }

        guard count > 0 else { return (1, 1, 1) }
        return (red / count, green / count, blue / count)
    }

    private nonisolated static func isForegroundPixel(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        background: (red: CGFloat, green: CGFloat, blue: CGFloat)
    ) -> Bool {
        let values = hsb(red: red, green: green, blue: blue)
        if values.brightness > 0.94, values.saturation < 0.10 {
            return false
        }

        let backgroundValues = hsb(red: background.red, green: background.green, blue: background.blue)
        let distance = sqrt(
            pow(red - background.red, 2) +
            pow(green - background.green, 2) +
            pow(blue - background.blue, 2)
        )

        if distance > 0.15 {
            return true
        }

        if values.saturation > backgroundValues.saturation + 0.16, values.brightness < 0.94 {
            return true
        }

        return values.brightness < backgroundValues.brightness - 0.18
    }

    private nonisolated static func horizontalSpanRatio(
        points: [(x: Int, y: Int)],
        minX: Int,
        maxX: Int,
        minY: Int,
        boxHeight: Int,
        startFraction: Double,
        endFraction: Double
    ) -> Double {
        let startY = minY + Int(Double(boxHeight) * startFraction)
        let endY = minY + Int(Double(boxHeight) * endFraction)
        let bandPoints = points.filter { $0.y >= startY && $0.y <= endY }
        guard let bandMinX = bandPoints.map(\.x).min(),
              let bandMaxX = bandPoints.map(\.x).max(),
              maxX > minX
        else {
            return 0
        }

        return Double(bandMaxX - bandMinX + 1) / Double(maxX - minX + 1)
    }

    private nonisolated static func lowerCenterOccupancy(
        points: [(x: Int, y: Int)],
        minX: Int,
        maxX: Int,
        minY: Int,
        boxHeight: Int
    ) -> Double {
        let centerStart = minX + Int(Double(maxX - minX + 1) * 0.42)
        let centerEnd = minX + Int(Double(maxX - minX + 1) * 0.58)
        let lowerStartY = minY + Int(Double(boxHeight) * 0.58)
        let lowerEndY = minY + Int(Double(boxHeight) * 0.96)
        guard centerEnd > centerStart, lowerEndY > lowerStartY else { return 0 }

        let occupied = points.filter {
            $0.x >= centerStart && $0.x <= centerEnd && $0.y >= lowerStartY && $0.y <= lowerEndY
        }.count
        let total = max(1, (centerEnd - centerStart + 1) * (lowerEndY - lowerStartY + 1))
        return Double(occupied) / Double(total)
    }

    private nonisolated static func sampledPixels(from image: UIImage, dimension: Int) -> [SampledPixel]? {
        let size = CGSize(width: dimension, height: dimension)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderedImage = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        guard let cgImage = renderedImage.cgImage else { return nil }
        var rawData = [UInt8](repeating: 0, count: dimension * dimension * 4)
        guard let context = CGContext(
            data: &rawData,
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bytesPerRow: dimension * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dimension, height: dimension))

        let center = CGFloat(dimension - 1) / 2
        return stride(from: 0, to: rawData.count, by: 4).compactMap { offset in
            let pixelIndex = offset / 4
            let x = CGFloat(pixelIndex % dimension)
            let y = CGFloat(pixelIndex / dimension)
            let alpha = CGFloat(rawData[offset + 3]) / 255
            guard alpha > 0.18 else { return nil }

            let red = CGFloat(rawData[offset]) / 255
            let green = CGFloat(rawData[offset + 1]) / 255
            let blue = CGFloat(rawData[offset + 2]) / 255
            let distance = hypot(x - center, y - center) / max(center, 1)
            let centerWeight = max(0.45, 1.20 - distance * 0.42)
            return SampledPixel(red: red, green: green, blue: blue, alpha: alpha, centerWeight: centerWeight)
        }
    }
    #endif

    private struct SampledPixel {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        let centerWeight: CGFloat

        nonisolated var looksLikeBrightBackground: Bool {
            let values = ClothingImageAnalyzer.hsb(red: red, green: green, blue: blue)
            return values.brightness > 0.92 && values.saturation < 0.10
        }

        nonisolated var analysisWeight: Double {
            let values = ClothingImageAnalyzer.hsb(red: red, green: green, blue: blue)
            return Double(alpha * centerWeight * (0.72 + values.saturation))
        }
    }

    private struct ColorBucket {
        var weight: Double = 0
        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0

        nonisolated init(weight: Double = 0, red: Double = 0, green: Double = 0, blue: Double = 0) {
            self.weight = weight
            self.red = red
            self.green = green
            self.blue = blue
        }

        nonisolated mutating func add(pixel: SampledPixel, weight: Double) {
            self.weight += weight
            red += Double(pixel.red) * weight
            green += Double(pixel.green) * weight
            blue += Double(pixel.blue) * weight
        }

        nonisolated var averageRGB: (red: Double, green: Double, blue: Double) {
            guard weight > 0 else { return (0, 0, 0) }
            return (red / weight, green / weight, blue / weight)
        }
    }

    private struct CategoryRule {
        let category: WardrobeCategory
        let keywords: [String]
        let weight: Double

        nonisolated init(category: WardrobeCategory, keywords: [String], weight: Double) {
            self.category = category
            self.keywords = keywords
            self.weight = weight
        }

        nonisolated func matches(_ identifier: String) -> Bool {
            keywords.contains { identifier.contains($0) }
        }
    }

    #if canImport(UIKit)
    private struct VisualSilhouetteProfile {
        let boxWidthRatio: Double
        let boxHeightRatio: Double
        let areaRatio: Double
        let upperSpanRatio: Double
        let middleSpanRatio: Double
        let lowerSpanRatio: Double
        let lowerCenterOccupancy: Double

        nonisolated var aspectRatio: Double {
            guard boxHeightRatio > 0 else { return 1 }
            return boxWidthRatio / boxHeightRatio
        }
    }
    #endif
}

#if canImport(UIKit) && canImport(CoreML)
private final class WearOrderClothingModelClassifier {
    nonisolated static let modelResourceName = "WearOrderClothingClassifier"
    nonisolated static let shared: WearOrderClothingModelClassifier? = {
        guard let modelURL = Bundle.main.url(forResource: modelResourceName, withExtension: "mlmodelc") else {
            return nil
        }

        guard let model = try? MLModel(contentsOf: modelURL) else {
            return nil
        }

        return WearOrderClothingModelClassifier(model: model)
    }()

    nonisolated(unsafe) private let model: MLModel
    private let imageInputName: String
    nonisolated(unsafe) private let imageConstraint: MLImageConstraint

    private nonisolated init?(model: MLModel) {
        guard let imageInput = model.modelDescription.inputDescriptionsByName.first(where: { $0.value.type == .image }),
              let constraint = imageInput.value.imageConstraint
        else {
            return nil
        }

        self.model = model
        self.imageInputName = imageInput.key
        self.imageConstraint = constraint
    }

    nonisolated func classificationLabels(for image: UIImage) -> [ClothingImageClassificationLabel]? {
        guard let pixelBuffer = pixelBuffer(from: image, constraint: imageConstraint) else {
            return nil
        }

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: [
            imageInputName: MLFeatureValue(pixelBuffer: pixelBuffer)
        ]) else {
            return nil
        }

        guard let prediction = try? model.prediction(from: provider) else {
            return nil
        }

        let labels = labels(from: prediction)
        return labels.isEmpty ? nil : labels
    }

    private nonisolated func labels(from prediction: MLFeatureProvider) -> [ClothingImageClassificationLabel] {
        var labelsByIdentifier: [String: ClothingImageClassificationLabel] = [:]
        var predictedIdentifier: String?

        if let predictedFeatureName = model.modelDescription.predictedFeatureName,
           let predictedValue = prediction.featureValue(for: predictedFeatureName),
           predictedValue.type == .string {
            predictedIdentifier = predictedValue.stringValue
        }

        for featureName in prediction.featureNames {
            guard let value = prediction.featureValue(for: featureName) else { continue }

            if value.type == .string, predictedIdentifier == nil {
                predictedIdentifier = value.stringValue
            } else if value.type == .dictionary {
                for (key, probability) in value.dictionaryValue {
                    guard let identifier = key as? String else { continue }
                    labelsByIdentifier[identifier] = ClothingImageClassificationLabel(
                        identifier: identifier,
                        confidence: Double(truncating: probability)
                    )
                }
            }
        }

        if let predictedIdentifier, !labelsByIdentifier.keys.contains(predictedIdentifier) {
            labelsByIdentifier[predictedIdentifier] = ClothingImageClassificationLabel(
                identifier: predictedIdentifier,
                confidence: 0.80
            )
        }

        return labelsByIdentifier.values.sorted { $0.confidence > $1.confidence }
    }

    private nonisolated func pixelBuffer(from image: UIImage, constraint: MLImageConstraint) -> CVPixelBuffer? {
        let width = max(1, constraint.pixelsWide)
        let height = max(1, constraint.pixelsHigh)
        let pixelAttributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        var pixelBuffer: CVPixelBuffer?

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            pixelAttributes,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        let drawRect = aspectFillRect(
            imageSize: image.size,
            targetSize: CGSize(width: CGFloat(width), height: CGFloat(height))
        )
        UIGraphicsPushContext(context)
        image.draw(in: drawRect)
        UIGraphicsPopContext()

        return pixelBuffer
    }

    private nonisolated func aspectFillRect(imageSize: CGSize, targetSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: targetSize)
        }

        let scale = max(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
}
#endif

#if canImport(UIKit)
private func aspectFitRect(imageSize: CGSize, targetSize: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0 else {
        return CGRect(origin: .zero, size: targetSize)
    }

    let scale = min(targetSize.width / imageSize.width, targetSize.height / imageSize.height)
    let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    return CGRect(
        x: (targetSize.width - scaledSize.width) / 2,
        y: (targetSize.height - scaledSize.height) / 2,
        width: scaledSize.width,
        height: scaledSize.height
    )
}

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        case .upMirrored:
            self = .upMirrored
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
#endif
