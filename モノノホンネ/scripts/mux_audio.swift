import Foundation
import AVFoundation

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let videoURL = cwd.appendingPathComponent("output/mononohonne_sample_10s.mp4")
let audioURL = cwd.appendingPathComponent("output/narration.aiff")
let outURL = cwd.appendingPathComponent("output/mononohonne_sample_10s_with_voice.mp4")
try? FileManager.default.removeItem(at: outURL)

let composition = AVMutableComposition()
let videoAsset = AVURLAsset(url: videoURL)
let audioAsset = AVURLAsset(url: audioURL)
let duration = CMTime(seconds: 10.0, preferredTimescale: 600)

guard let srcVideo = videoAsset.tracks(withMediaType: .video).first,
      let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
    fatalError("video track not found")
}
try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: srcVideo, at: .zero)
videoTrack.preferredTransform = srcVideo.preferredTransform

if let srcAudio = audioAsset.tracks(withMediaType: .audio).first,
   let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
    let adur = min(audioAsset.duration, duration)
    try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: adur), of: srcAudio, at: .zero)
}

guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { fatalError("export session") }
export.outputURL = outURL
export.outputFileType = .mp4
export.shouldOptimizeForNetworkUse = true
let sema = DispatchSemaphore(value: 0)
export.exportAsynchronously { sema.signal() }
sema.wait()
if export.status != .completed {
    fputs("Export failed: \(export.status) \(String(describing: export.error))\n", stderr)
    exit(1)
}
print(outURL.path)
