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

struct ClothingImageColorSuggestion: Equatable {
    let colorName: String
    let confidence: Double
    let red: Double
    let green: Double
    let blue: Double

    var confidencePercent: Int {
        Int((confidence * 100).rounded())
    }
}

struct ClothingImageClassificationLabel: Equatable {
    let identifier: String
    let confidence: Double
}

struct ClothingImageCategorySuggestion: Equatable {
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
    private static let sampleDimension = 44

    #if canImport(UIKit)
    static func suggestDominantColor(from data: Data) -> ClothingImageColorSuggestion? {
        guard let image = UIImage(data: data) else { return nil }
        return suggestDominantColor(from: image)
    }

    static func suggestDominantColor(from image: UIImage) -> ClothingImageColorSuggestion? {
        guard let pixels = sampledPixels(from: image, dimension: sampleDimension) else { return nil }
        return dominantColorSuggestion(from: pixels)
    }
    #endif

    static func suggestCategory(from data: Data) -> ClothingImageCategorySuggestion? {
        #if canImport(UIKit) && canImport(CoreML)
        if let customModelSuggestion = customModelCategorySuggestion(from: data) {
            return customModelSuggestion
        }
        #endif

        return visionCategorySuggestion(from: data)
    }

    static func categorySuggestion(from labels: [ClothingImageClassificationLabel]) -> ClothingImageCategorySuggestion? {
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

        let matchedLabel = bestLabelByCategory[best.key]?.identifier ?? best.key.rawValue
        return ClothingImageCategorySuggestion(
            category: best.key,
            confidence: min(0.94, max(0.32, best.value)),
            matchedLabel: matchedLabel
        )
    }

    #if canImport(UIKit) && canImport(CoreML)
    private static func customModelCategorySuggestion(from data: Data) -> ClothingImageCategorySuggestion? {
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

    private static func visionCategorySuggestion(from data: Data) -> ClothingImageCategorySuggestion? {
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

    static func closestPaletteColorName(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
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

    private static func dominantColorSuggestion(from pixels: [SampledPixel]) -> ClothingImageColorSuggestion? {
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

    private static func hsb(red: CGFloat, green: CGFloat, blue: CGFloat) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
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

    private static func normalizedClassificationIdentifier(_ identifier: String) -> String {
        identifier
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func exactCategory(for identifier: String) -> WardrobeCategory? {
        switch identifier {
        case WardrobeCategory.top.rawValue, "top", "upper", "upper body", "tops":
            return .top
        case WardrobeCategory.outerwear.rawValue, "outerwear", "outer wear", "coat jacket":
            return .outerwear
        case WardrobeCategory.bottom.rawValue, "bottom", "bottoms", "pants bottom", "lower body":
            return .bottom
        case WardrobeCategory.skirt.rawValue, "skirt", "skirts", "dress skirt":
            return .skirt
        case WardrobeCategory.shoes.rawValue, "shoes", "shoe", "footwear":
            return .shoes
        case WardrobeCategory.bag.rawValue, "bag", "bags", "handbag", "purse":
            return .bag
        case WardrobeCategory.accessory.rawValue, "accessory", "accessories", "jewelry":
            return .accessory
        case WardrobeCategory.hat.rawValue, "hat", "hats", "cap":
            return .hat
        default:
            return nil
        }
    }

    private static func addCategoryScore(
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

    private static let categoryRules: [CategoryRule] = [
        .init(category: .shoes, keywords: ["shoe", "shoes", "sneaker", "footwear", "boot", "boots", "sandal", "loafer", "heel", "slipper", "cleat"], weight: 1.28),
        .init(category: .bag, keywords: ["handbag", "shoulder bag", "tote", "purse", "backpack", "bag", "wallet", "suitcase", "duffel"], weight: 1.24),
        .init(category: .hat, keywords: ["hat", "cap", "beanie", "beret", "fedora", "sun hat"], weight: 1.22),
        .init(category: .accessory, keywords: ["necklace", "bracelet", "earring", "jewelry", "ring", "watch", "belt", "scarf", "tie", "glove", "sunglasses"], weight: 1.12),
        .init(category: .skirt, keywords: ["skirt", "dress", "gown", "robe", "kimono"], weight: 1.08),
        .init(category: .bottom, keywords: ["pants", "jeans", "trouser", "trousers", "shorts", "leggings", "slacks", "denim", "jogger"], weight: 1.06),
        .init(category: .outerwear, keywords: ["coat", "jacket", "blazer", "cardigan", "parka", "overcoat", "hoodie", "windbreaker", "suit"], weight: 1.02),
        .init(category: .top, keywords: ["shirt", "t shirt", "tshirt", "blouse", "top", "jersey", "sweatshirt", "pullover", "polo", "tank top", "vest"], weight: 0.82),
        .init(category: .top, keywords: ["apparel", "clothing", "garment"], weight: 0.20)
    ]

    #if canImport(UIKit)
    private static func sampledPixels(from image: UIImage, dimension: Int) -> [SampledPixel]? {
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

        var looksLikeBrightBackground: Bool {
            let values = ClothingImageAnalyzer.hsb(red: red, green: green, blue: blue)
            return values.brightness > 0.92 && values.saturation < 0.10
        }

        var analysisWeight: Double {
            let values = ClothingImageAnalyzer.hsb(red: red, green: green, blue: blue)
            return Double(alpha * centerWeight * (0.72 + values.saturation))
        }
    }

    private struct ColorBucket {
        var weight: Double = 0
        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0

        mutating func add(pixel: SampledPixel, weight: Double) {
            self.weight += weight
            red += Double(pixel.red) * weight
            green += Double(pixel.green) * weight
            blue += Double(pixel.blue) * weight
        }

        var averageRGB: (red: Double, green: Double, blue: Double) {
            guard weight > 0 else { return (0, 0, 0) }
            return (red / weight, green / weight, blue / weight)
        }
    }

    private struct CategoryRule {
        let category: WardrobeCategory
        let keywords: [String]
        let weight: Double

        func matches(_ identifier: String) -> Bool {
            keywords.contains { identifier.contains($0) }
        }
    }
}

#if canImport(UIKit) && canImport(CoreML)
private final class WearOrderClothingModelClassifier {
    static let modelResourceName = "WearOrderClothingClassifier"
    static let shared: WearOrderClothingModelClassifier? = {
        guard let modelURL = Bundle.main.url(forResource: modelResourceName, withExtension: "mlmodelc") else {
            return nil
        }

        guard let model = try? MLModel(contentsOf: modelURL) else {
            return nil
        }

        return WearOrderClothingModelClassifier(model: model)
    }()

    private let model: MLModel
    private let imageInputName: String
    private let imageConstraint: MLImageConstraint

    private init?(model: MLModel) {
        guard let imageInput = model.modelDescription.inputDescriptionsByName.first(where: { $0.value.type == .image }),
              let constraint = imageInput.value.imageConstraint
        else {
            return nil
        }

        self.model = model
        self.imageInputName = imageInput.key
        self.imageConstraint = constraint
    }

    func classificationLabels(for image: UIImage) -> [ClothingImageClassificationLabel]? {
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

    private func labels(from prediction: MLFeatureProvider) -> [ClothingImageClassificationLabel] {
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

        if let predictedIdentifier, labelsByIdentifier[predictedIdentifier] == nil {
            labelsByIdentifier[predictedIdentifier] = ClothingImageClassificationLabel(
                identifier: predictedIdentifier,
                confidence: 0.80
            )
        }

        return labelsByIdentifier.values.sorted { $0.confidence > $1.confidence }
    }

    private func pixelBuffer(from image: UIImage, constraint: MLImageConstraint) -> CVPixelBuffer? {
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

    private func aspectFillRect(imageSize: CGSize, targetSize: CGSize) -> CGRect {
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
private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
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
