import XCTest
@testable import 衣橱存储

final class ClothingBackgroundImageProcessorTests: XCTestCase {
    func testBackgroundProcessingErrorsHaveUserFacingMessages() {
        let errors: [ClothingBackgroundImageProcessingError] = [
            .unsupported,
            .invalidImage,
            .noForegroundDetected,
            .renderFailed
        ]

        for error in errors {
            XCTAssertFalse(error.userMessage.isEmpty)
        }
    }

    func testInvalidImageDataFailsBeforeProcessing() {
        guard ClothingBackgroundImageProcessor.isWhiteBackgroundGenerationAvailable else {
            return
        }

        XCTAssertThrowsError(try ClothingBackgroundImageProcessor.whiteBackgroundJPEGData(from: Data())) { error in
            XCTAssertEqual(error as? ClothingBackgroundImageProcessingError, .invalidImage)
        }
    }
}
