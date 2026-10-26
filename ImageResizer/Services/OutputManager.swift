import Foundation

public final class OutputManager: @unchecked Sendable {
    public static let shared = OutputManager()

    public init() {}

    /// Determines the destination URL for a given input file and resize configuration.
    public func resolveDestinationURL(
        for sourceURL: URL,
        configuration: ResizeConfiguration,
        presetName: String? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        // 1. Resolve destination directory
        let destinationDir: URL
        switch configuration.destinationMode {
        case .subfolder:
            let parentDir = sourceURL.deletingLastPathComponent()
            let subfolder = configuration.subfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
            let folderName = subfolder.isEmpty ? "Resized" : subfolder
            destinationDir = parentDir.appendingPathComponent(folderName, isDirectory: true)

        case .sameFolder:
            destinationDir = sourceURL.deletingLastPathComponent()

        case .customFolder:
            if let customPath = configuration.customDestinationPath, !customPath.isEmpty {
                destinationDir = URL(fileURLWithPath: customPath, isDirectory: true)
            } else {
                destinationDir = sourceURL.deletingLastPathComponent()
            }
        }

        // Ensure directory exists
        if !fileManager.fileExists(atPath: destinationDir.path) {
            try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        }

        // 2. Build base filename
        let originalBaseName = sourceURL.deletingPathExtension().lastPathComponent

        var suffix = configuration.filenameSuffix
        if configuration.appendPresetNameToFilename, let presetName = presetName, !presetName.isEmpty {
            let sanitizedPreset = presetName
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            suffix += "_\(sanitizedPreset)"
        }

        // 3. Resolve target extension
        let targetExtension: String
        if configuration.outputFormat == .original {
            targetExtension = sourceURL.pathExtension
        } else {
            targetExtension = configuration.outputFormat.fileExtension
        }

        let baseOutputName = "\(originalBaseName)\(suffix)"
        var candidateURL = destinationDir.appendingPathComponent(baseOutputName).appendingPathExtension(targetExtension)

        // Safety check: Never overwrite original source file directly
        let isSameAsSource = (candidateURL.standardizedFileURL.path == sourceURL.standardizedFileURL.path)

        // 4. Handle collisions
        if isSameAsSource || fileManager.fileExists(atPath: candidateURL.path) {
            switch configuration.collisionHandling {
            case .renameWithNumber:
                candidateURL = generateUniqueURL(
                    in: destinationDir,
                    baseName: baseOutputName,
                    fileExtension: targetExtension,
                    fileManager: fileManager
                )

            case .overwrite:
                if isSameAsSource {
                    // Even if user chose overwrite, do not overwrite original source file!
                    candidateURL = generateUniqueURL(
                        in: destinationDir,
                        baseName: "\(baseOutputName)_copy",
                        fileExtension: targetExtension,
                        fileManager: fileManager
                    )
                }

            case .skip:
                if !isSameAsSource {
                    // Let caller handle skip or return existing candidate
                }
            }
        }

        return candidateURL
    }

    /// Appends incrementing counter (1), (2), etc. until an unused path is found
    public func generateUniqueURL(
        in directory: URL,
        baseName: String,
        fileExtension: String,
        fileManager: FileManager = .default
    ) -> URL {
        var counter = 1
        var candidate: URL

        repeat {
            let filename = "\(baseName) (\(counter))"
            candidate = directory.appendingPathComponent(filename).appendingPathExtension(fileExtension)
            counter += 1
        } while fileManager.fileExists(atPath: candidate.path)

        return candidate
    }
}
