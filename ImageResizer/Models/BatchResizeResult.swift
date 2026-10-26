import Foundation

public struct BatchResizeResult: Equatable {
    public let totalCount: Int
    public let succeededCount: Int
    public let failedCount: Int
    public let outputURLs: [URL]
    public let errors: [(filename: String, message: String)]
    public let destinationDirectory: URL?
    public let duration: TimeInterval

    public init(
        totalCount: Int,
        succeededCount: Int,
        failedCount: Int,
        outputURLs: [URL] = [],
        errors: [(filename: String, message: String)] = [],
        destinationDirectory: URL? = nil,
        duration: TimeInterval = 0
    ) {
        self.totalCount = totalCount
        self.succeededCount = succeededCount
        self.failedCount = failedCount
        self.outputURLs = outputURLs
        self.errors = errors
        self.destinationDirectory = destinationDirectory
        self.duration = duration
    }

    public static func == (lhs: BatchResizeResult, rhs: BatchResizeResult) -> Bool {
        lhs.totalCount == rhs.totalCount &&
        lhs.succeededCount == rhs.succeededCount &&
        lhs.failedCount == rhs.failedCount &&
        lhs.outputURLs == rhs.outputURLs &&
        lhs.destinationDirectory == rhs.destinationDirectory
    }
}
