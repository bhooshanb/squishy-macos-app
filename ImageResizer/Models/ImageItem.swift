import Foundation
import AppKit

public enum ResizeItemStatus: Equatable {
    case idle
    case processing
    case succeeded(outputURL: URL)
    case failed(errorDescription: String)

    public var isSuccess: Bool {
        if case .succeeded = self { return true }
        return false
    }

    public var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    public var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }
}

/// Represents an image file in the queue.
public final class ImageItem: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: UUID
    public let url: URL
    public let filename: String
    public let fileSize: Int64
    public let originalDimensions: ImageDimensions
    public let utiString: String?
    public let formatName: String

    @Published public var thumbnail: NSImage?
    @Published public var status: ResizeItemStatus = .idle
    @Published public var outputDimensions: ImageDimensions?

    public init(
        id: UUID = UUID(),
        url: URL,
        filename: String,
        fileSize: Int64,
        originalDimensions: ImageDimensions,
        utiString: String? = nil,
        formatName: String = "Image",
        thumbnail: NSImage? = nil
    ) {
        self.id = id
        self.url = url
        self.filename = filename
        self.fileSize = fileSize
        self.originalDimensions = originalDimensions
        self.utiString = utiString
        self.formatName = formatName
        self.thumbnail = thumbnail
        self.status = .idle
    }

    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
