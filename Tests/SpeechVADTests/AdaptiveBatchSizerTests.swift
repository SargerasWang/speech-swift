import XCTest
@testable import SpeechVAD

final class AdaptiveBatchSizerTests: XCTestCase {

    func testStartsAtBatchSizeOne() {
        let sizer = AdaptiveBatchSizer()
        XCTAssertEqual(sizer.currentBatchSize, 1)
        XCTAssertFalse(sizer.isLocked)
    }

    func testSlowStartDoubles() {
        var sizer = AdaptiveBatchSizer()

        // batch=1: 10 items/sec
        sizer.reportCompletion(itemsProcessed: 1, elapsedSeconds: 0.1)
        XCTAssertEqual(sizer.currentBatchSize, 2)
        XCTAssertFalse(sizer.isLocked)

        // batch=2: 20 items/sec (2x improvement)
        sizer.reportCompletion(itemsProcessed: 2, elapsedSeconds: 0.1)
        XCTAssertEqual(sizer.currentBatchSize, 4)
        XCTAssertFalse(sizer.isLocked)

        // batch=4: 40 items/sec (2x improvement)
        sizer.reportCompletion(itemsProcessed: 4, elapsedSeconds: 0.1)
        XCTAssertEqual(sizer.currentBatchSize, 8)
        XCTAssertFalse(sizer.isLocked)
    }

    func testLocksOnPlateau() {
        var sizer = AdaptiveBatchSizer()

        // batch=1: 10 items/sec
        sizer.reportCompletion(itemsProcessed: 1, elapsedSeconds: 0.1)
        XCTAssertEqual(sizer.currentBatchSize, 2)

        // batch=2: 10.5 items/sec (only 5% improvement, below 10% threshold)
        sizer.reportCompletion(itemsProcessed: 2, elapsedSeconds: 0.19)
        XCTAssertEqual(sizer.currentBatchSize, 1)  // locked at previous
        XCTAssertTrue(sizer.isLocked)
    }

    func testLockedSizerIgnoresReports() {
        var sizer = AdaptiveBatchSizer()
        sizer.reportCompletion(itemsProcessed: 1, elapsedSeconds: 0.1)
        sizer.reportCompletion(itemsProcessed: 2, elapsedSeconds: 0.19)
        XCTAssertTrue(sizer.isLocked)
        let lockedSize = sizer.currentBatchSize

        // Further reports should not change the batch size
        sizer.reportCompletion(itemsProcessed: 100, elapsedSeconds: 0.001)
        XCTAssertEqual(sizer.currentBatchSize, lockedSize)
    }

    func testFailureHalvesAndLocks() {
        var sizer = AdaptiveBatchSizer()
        sizer.reportCompletion(itemsProcessed: 1, elapsedSeconds: 0.1)
        sizer.reportCompletion(itemsProcessed: 2, elapsedSeconds: 0.05)
        sizer.reportCompletion(itemsProcessed: 4, elapsedSeconds: 0.025)
        XCTAssertEqual(sizer.currentBatchSize, 8)

        sizer.reportFailure()
        XCTAssertEqual(sizer.currentBatchSize, 4)
        XCTAssertTrue(sizer.isLocked)
    }

    func testFailureAtOneStaysAtOne() {
        var sizer = AdaptiveBatchSizer()
        XCTAssertEqual(sizer.currentBatchSize, 1)

        sizer.reportFailure()
        XCTAssertEqual(sizer.currentBatchSize, 1)
        XCTAssertTrue(sizer.isLocked)
    }

    func testMaxBatchSizeCap() {
        var sizer = AdaptiveBatchSizer(maxBatchSize: 8)

        // Keep reporting great throughput improvements
        var time = 0.1
        for _ in 0..<10 {
            sizer.reportCompletion(itemsProcessed: sizer.currentBatchSize, elapsedSeconds: time)
            time *= 0.4  // throughput keeps improving
        }

        XCTAssertEqual(sizer.currentBatchSize, 8)
        XCTAssertTrue(sizer.isLocked)
    }
}
