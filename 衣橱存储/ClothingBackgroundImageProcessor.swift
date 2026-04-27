import Foundation

#if canImport(UIKit)
import UIKit
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
#endif

enum ClothingBackgroundImageProcessingError: Error, Equatable {
    case unsupported
    case invalidImage
    case noForegroundDetected
    case renderFailed

    var userMessage: String {
        switch self {
        case .unsupported:
            "当前设备暂不支持本地白底图生成。"
        case .invalidImage:
            "图片无法读取，请换一张更清晰的照片。"
        case .noForegroundDetected:
            "没有识别到清晰的衣物主体，请换成背景更简单的照片。"
        case .renderFailed:
            "白底图生成失败，请重试或保留原图。"
        }
    }
}

enum ClothingBackgroundImageProcessor {
    nonisolated static var isWhiteBackgroundGenerationAvailable: Bool {
        #if canImport(UIKit) && canImport(Vision) && canImport(CoreImage)
        if #available(iOS 17.0, *) {
            return true
        }
        return false
        #else
        return false
        #endif
    }

    nonisolated static func whiteBackgroundJPEGData(from data: Data) throws -> Data {
        #if canImport(UIKit) && canImport(Vision) && canImport(CoreImage)
        guard isWhiteBackgroundGenerationAvailable else {
            throw ClothingBackgroundImageProcessingError.unsupported
        }
        guard
            let image = UIImage(data: data),
            let normalizedImage = image.normalizedForProcessing(),
            let cgImage = normalizedImage.cgImage
        else {
            throw ClothingBackgroundImageProcessingError.invalidImage
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])

        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw ClothingBackgroundImageProcessingError.noForegroundDetected
        }

        let maskPixelBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: handler
        )
        let inputImage = CIImage(cgImage: cgImage)
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        let backgroundImage = CIImage(color: .white).cropped(to: inputImage.extent)

        let filter = CIFilter.blendWithMask()
        filter.inputImage = inputImage
        filter.backgroundImage = backgroundImage
        filter.maskImage = maskImage

        guard
            let outputImage = filter.outputImage,
            let outputCGImage = CIContext(options: [.cacheIntermediates: false]).createCGImage(
                outputImage,
                from: inputImage.extent,
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        else {
            throw ClothingBackgroundImageProcessingError.renderFailed
        }

        let output = UIImage(cgImage: outputCGImage, scale: normalizedImage.scale, orientation: .up)
        guard let jpegData = output.jpegData(compressionQuality: 0.90) else {
            throw ClothingBackgroundImageProcessingError.renderFailed
        }
        return ImageDataOptimizer.optimizedJPEGData(from: jpegData) ?? jpegData
        #else
        throw ClothingBackgroundImageProcessingError.unsupported
        #endif
    }
}

#if canImport(UIKit)
private extension UIImage {
    nonisolated func normalizedForProcessing() -> UIImage? {
        if imageOrientation == .up, cgImage != nil {
            return self
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
#endif
