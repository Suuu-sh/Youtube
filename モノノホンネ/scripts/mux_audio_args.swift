import Foundation
import AVFoundation

let args = CommandLine.arguments
if args.count < 4 {
    fputs("Usage: swift scripts/mux_audio_args.swift <video> <audio> <output> [durationSeconds]\n", stderr)
    exit(2)
}
let videoURL = URL(fileURLWithPath: args[1])
let audioURL = URL(fileURLWithPath: args[2])
let outURL = URL(fileURLWithPath: args[3])
let durationSeconds = args.count >= 5 ? Double(args[4])! : 10.0
try? FileManager.default.removeItem(at: outURL)

let composition = AVMutableComposition()
let videoAsset = AVURLAsset(url: videoURL)
let audioAsset = AVURLAsset(url: audioURL)
let duration = CMTime(seconds: durationSeconds, preferredTimescale: 600)

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
