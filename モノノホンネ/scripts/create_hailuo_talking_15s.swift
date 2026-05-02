import Foundation
import AVFoundation

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let inputVideoURL = cwd.appendingPathComponent("output/hailuo_milk_carton_6s.mp4")
let audioURL = cwd.appendingPathComponent("output/milk_carton_narration_15s.aiff")
let outputURL = cwd.appendingPathComponent("output/hailuo_milk_carton_talking_15s.mp4")
try? FileManager.default.removeItem(at: outputURL)

let targetDuration = CMTime(seconds: 15.0, preferredTimescale: 600)
let composition = AVMutableComposition()
let videoAsset = AVURLAsset(url: inputVideoURL)
let audioAsset = AVURLAsset(url: audioURL)

guard let sourceVideoTrack = videoAsset.tracks(withMediaType: .video).first,
      let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
    fatalError("Video track not found")
}

var cursor = CMTime.zero
let sourceDuration = videoAsset.duration
while cursor < targetDuration {
    let remaining = targetDuration - cursor
    let chunkDuration = min(sourceDuration, remaining)
    try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: chunkDuration), of: sourceVideoTrack, at: cursor)
    cursor = cursor + chunkDuration
}
compositionVideoTrack.preferredTransform = sourceVideoTrack.preferredTransform

if let sourceAudioTrack = audioAsset.tracks(withMediaType: .audio).first,
   let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
    let audioDuration = min(audioAsset.duration, targetDuration)
    try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audioDuration), of: sourceAudioTrack, at: .zero)
}

guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
    fatalError("Failed to create export session")
}
export.outputURL = outputURL
export.outputFileType = .mp4
export.timeRange = CMTimeRange(start: .zero, duration: targetDuration)
export.shouldOptimizeForNetworkUse = true

let semaphore = DispatchSemaphore(value: 0)
export.exportAsynchronously { semaphore.signal() }
semaphore.wait()

if export.status != .completed {
    fputs("Export failed: \(export.status) \(String(describing: export.error))\n", stderr)
    exit(1)
}
print(outputURL.path)
