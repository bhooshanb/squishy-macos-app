import AVFoundation
import AVFAudio
import Foundation

public enum VideoCompressionError: LocalizedError {
    case exportUnavailable
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .exportUnavailable: return "This video format could not be decoded or encoded as MP4."
        case .exportFailed(let message): return message
        }
    }
}

/// AVFoundation reader/writer transcode using decoded frames and an explicit H.264 target bitrate.
public final class VideoCompressionEngine: @unchecked Sendable {
    public static let shared = VideoCompressionEngine()
    private init() {}

    public func compress(from source: URL, to destination: URL, outputBitrate: Int, control: BatchProcessingControl) async throws {
        let asset = AVURLAsset(url: source)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else { throw VideoCompressionError.exportUnavailable }
        let sourceBitrate = Int(try await videoTrack.load(.estimatedDataRate))
        let targetBitrate = max(100_000, min(outputBitrate, sourceBitrate > 0 ? sourceBitrate : outputBitrate))
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let encodedWidth = max(2, Int(naturalSize.width) / 2 * 2)
        let encodedHeight = max(2, Int(naturalSize.height) / 2 * 2)

        try? FileManager.default.removeItem(at: destination)
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        writer.metadata = []

        // Decode to uncompressed pixel buffers. Passing compressed source samples to a re-encoding
        // AVAssetWriterInput is invalid and was the source of the reported Objective-C exception.
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else { throw VideoCompressionError.exportUnavailable }
        reader.add(videoOutput)

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: encodedWidth,
            AVVideoHeightKey: encodedHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: targetBitrate,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ])
        videoInput.expectsMediaDataInRealTime = false
        // Preserve the source track matrix. For rotated source media the encoded dimensions stay
        // in the unrotated coordinate space and the preferred transform carries display orientation.
        videoInput.transform = transform
        guard writer.canAdd(videoInput) else { throw VideoCompressionError.exportUnavailable }
        writer.add(videoInput)

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        var audioOutput: AVAssetReaderTrackOutput?
        var audioInput: AVAssetWriterInput?
        if let track = audioTracks.first {
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ])
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVEncoderBitRateKey: 128_000,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 2
            ])
            if reader.canAdd(output), writer.canAdd(input) {
                reader.add(output)
                writer.add(input)
                audioOutput = output
                audioInput = input
            }
        }

        guard reader.startReading() else { throw reader.error ?? VideoCompressionError.exportUnavailable }
        guard writer.startWriting() else { reader.cancelReading(); throw writer.error ?? VideoCompressionError.exportUnavailable }
        writer.startSession(atSourceTime: .zero)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let state = VideoWriterPumpState()
                state.start(
                    reader: reader,
                    writer: writer,
                    videoOutput: videoOutput,
                    videoInput: videoInput,
                    audioOutput: audioOutput,
                    audioInput: audioInput,
                    control: control
                ) { result in
                    continuation.resume(with: result)
                }
            }
        } catch {
            if control.isStopped() { try? FileManager.default.removeItem(at: destination) }
            throw error
        }
    }
}

/// Owns append callbacks and serializes completion without blocking an async executor thread.
private final class VideoWriterPumpState: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private var pendingTracks = 0

    func start(
        reader: AVAssetReader,
        writer: AVAssetWriter,
        videoOutput: AVAssetReaderTrackOutput,
        videoInput: AVAssetWriterInput,
        audioOutput: AVAssetReaderTrackOutput?,
        audioInput: AVAssetWriterInput?,
        control: BatchProcessingControl,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        pendingTracks = audioInput == nil ? 1 : 2
        pump(output: videoOutput, input: videoInput, queue: "squishy.video.encode", reader: reader, writer: writer, control: control, completion: completion)
        if let audioOutput, let audioInput {
            pump(output: audioOutput, input: audioInput, queue: "squishy.audio.encode", reader: reader, writer: writer, control: control, completion: completion)
        }
    }

    private func pump(
        output: AVAssetReaderTrackOutput,
        input: AVAssetWriterInput,
        queue: String,
        reader: AVAssetReader,
        writer: AVAssetWriter,
        control: BatchProcessingControl,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        input.requestMediaDataWhenReady(on: DispatchQueue(label: queue)) { [self] in
            while input.isReadyForMoreMediaData {
                guard control.waitUntilRunning() else {
                    reader.cancelReading()
                    writer.cancelWriting()
                    finishOnce(.failure(CancellationError()), completion: completion)
                    return
                }
                guard reader.status == .reading else {
                    input.markAsFinished()
                    finishIfReady(reader: reader, writer: writer, error: reader.error, completion: completion)
                    return
                }
                guard let sample = output.copyNextSampleBuffer() else {
                    input.markAsFinished()
                    trackFinished(reader: reader, writer: writer, completion: completion)
                    return
                }
                if !input.append(sample) {
                    reader.cancelReading()
                    writer.cancelWriting()
                    finishOnce(.failure(writer.error ?? reader.error ?? VideoCompressionError.exportUnavailable), completion: completion)
                    return
                }
            }
        }
    }

    private func trackFinished(reader: AVAssetReader, writer: AVAssetWriter, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        pendingTracks -= 1
        let allFinished = pendingTracks == 0
        lock.unlock()
        if allFinished { finishIfReady(reader: reader, writer: writer, error: reader.error, completion: completion) }
    }

    private func finishIfReady(reader: AVAssetReader, writer: AVAssetWriter, error: Error?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let error else {
            if reader.status == .completed || reader.status == .reading {
                writer.finishWriting { [self] in
                    if writer.status == .completed { finishOnce(.success(()), completion: completion) }
                    else { finishOnce(.failure(writer.error ?? VideoCompressionError.exportUnavailable), completion: completion) }
                }
            } else {
                writer.cancelWriting()
                finishOnce(.failure(VideoCompressionError.exportFailed("Video decoding ended with status \(reader.status.rawValue).")), completion: completion)
            }
            return
        }
        reader.cancelReading()
        writer.cancelWriting()
        finishOnce(.failure(error), completion: completion)
    }

    private func finishOnce(_ result: Result<Void, Error>, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        let shouldComplete = !completed
        completed = true
        lock.unlock()
        if shouldComplete { completion(result) }
    }
}

/// Shared pause/stop gate. Video callbacks wait here between frames; stop wakes them immediately.
public final class BatchProcessingControl: @unchecked Sendable {
    private let condition = NSCondition()
    private var paused = false
    private var stopped = false

    public func pause() {
        condition.lock(); paused = true; condition.unlock()
    }
    public func resume() {
        condition.lock(); paused = false; condition.broadcast(); condition.unlock()
    }
    public func stop() {
        condition.lock(); stopped = true; paused = false; condition.broadcast(); condition.unlock()
    }
    public func reset() {
        condition.lock(); paused = false; stopped = false; condition.broadcast(); condition.unlock()
    }
    public func isStopped() -> Bool {
        condition.lock(); defer { condition.unlock() }; return stopped
    }
    public func waitUntilRunning() -> Bool {
        condition.lock()
        while paused && !stopped { condition.wait() }
        let shouldContinue = !stopped
        condition.unlock()
        return shouldContinue
    }
}
