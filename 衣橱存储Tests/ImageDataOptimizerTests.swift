import XCTest
@testable import 衣橱存储
#if canImport(UIKit)
import UIKit
#endif

final class ImageDataOptimizerTests: XCTestCase {
    func testScaledSizePreservesAspectRatio() {
        let scaledSize = ImageDataOptimizer.scaledSize(
            for: CGSize(width: 3000, height: 1500),
            maxDimension: 1200
        )

        XCTAssertEqual(scaledSize.width, 1200, accuracy: 0.1)
        XCTAssertEqual(scaledSize.height, 600, accuracy: 0.1)
    }

    func testImportStatusReportsCompression() {
        let status = ClothingImageImportStatus(originalByteCount: 2_000_000, storedByteCount: 600_000)

        XCTAssertTrue(status.didCompress)
        XCTAssertTrue(status.message.contains("已优化图片"))
    }

    #if canImport(UIKit)
    func testOptimizedJPEGDataDoesNotGrowImageData() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 1200))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1200))
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 200, y: 200, width: 900, height: 620))
        }
        let originalData = try XCTUnwrap(image.jpegData(compressionQuality: 1.0))
        let optimizedData = try XCTUnwrap(ImageDataOptimizer.optimizedJPEGData(from: originalData))

        XCTAssertLessThanOrEqual(optimizedData.count, originalData.count)
    }

    func testThumbnailJPEGDataKeepsSmallPreviewBudget() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1800, height: 1200))
        let image = renderer.image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1800, height: 1200))
            UIColor.white.setFill()
            context.fill(CGRect(x: 220, y: 180, width: 1120, height: 760))
        }
        let originalData = try XCTUnwrap(image.jpegData(compressionQuality: 1.0))
        let thumbnailData = try XCTUnwrap(ImageDataOptimizer.thumbnailJPEGData(from: originalData))
        let thumbnailImage = try XCTUnwrap(UIImage(data: thumbnailData))

        XCTAssertLessThanOrEqual(thumbnailData.count, ImageDataOptimizer.thumbnailMaxByteCount)
        XCTAssertLessThanOrEqual(max(thumbnailImage.size.width, thumbnailImage.size.height), ImageDataOptimizer.thumbnailMaxDimension)
    }
    #endif
}
