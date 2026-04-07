import Foundation

/// Adaptive batch size discovery using TCP slow-start strategy.
///
/// Starts at batch size 1 and doubles until throughput stops improving,
/// then locks at the optimal size. Works for any Apple Silicon chip —
/// M1 might saturate at 8, M5 Max might reach 64.
///
/// Usage:
/// ```swift
/// var sizer = AdaptiveBatchSizer()
/// while hasWork {
///     let batch = min(sizer.currentBatchSize, remaining)
///     let start = CFAbsoluteTimeGetCurrent()
///     processBatch(batch)
///     let elapsed = CFAbsoluteTimeGetCurrent() - start
///     sizer.reportCompletion(itemsProcessed: batch, elapsedSeconds: elapsed)
/// }
/// ```
struct AdaptiveBatchSizer {

    /// Current batch size to use.
    private(set) var currentBatchSize: Int = 1

    /// Whether the optimal batch size has been found and locked.
    private(set) var isLocked: Bool = false

    /// Hard upper limit for batch size.
    let maxBatchSize: Int

    private var previousThroughput: Double = 0
    private var previousBatchSize: Int = 1

    init(maxBatchSize: Int = 128) {
        self.maxBatchSize = maxBatchSize
    }

    /// Create a sizer locked at a fixed batch size (no adaptation).
    static func fixed(_ batchSize: Int) -> AdaptiveBatchSizer {
        var sizer = AdaptiveBatchSizer(maxBatchSize: batchSize)
        sizer.currentBatchSize = batchSize
        sizer.isLocked = true
        return sizer
    }

    /// Report that a batch completed successfully.
    ///
    /// Updates the batch size based on throughput comparison:
    /// - Throughput improved by ≥10%: double the batch size
    /// - Throughput plateaued or decreased: lock at previous batch size
    ///
    /// - Parameters:
    ///   - itemsProcessed: number of items in the completed batch
    ///   - elapsedSeconds: wall-clock time for the batch
    mutating func reportCompletion(itemsProcessed: Int, elapsedSeconds: Double) {
        guard !isLocked else { return }
        guard elapsedSeconds > 0 else { return }

        let throughput = Double(itemsProcessed) / elapsedSeconds

        if previousThroughput > 0 {
            let improvement = (throughput - previousThroughput) / previousThroughput
            if improvement < 0.10 {
                // Throughput did not improve enough — lock at previous size
                currentBatchSize = previousBatchSize
                isLocked = true
                return
            }
        }

        // Throughput improved — remember and double
        previousThroughput = throughput
        previousBatchSize = currentBatchSize
        currentBatchSize = min(currentBatchSize * 2, maxBatchSize)

        if currentBatchSize >= maxBatchSize {
            isLocked = true
        }
    }

    /// Report that a batch failed (e.g. OOM).
    ///
    /// Halves the batch size and locks it. Minimum is 1.
    mutating func reportFailure() {
        currentBatchSize = max(currentBatchSize / 2, 1)
        isLocked = true
    }
}
