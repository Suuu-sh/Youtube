#!/usr/bin/env swift
import Foundation
import AVFoundation

enum MixError: Error, CustomStringConvertible {
    case invalidArguments
    case missingVideoTrack
    case missingVideoAudioTrack
    case missingBGMTrack
    case cannotCreateTrack(String)
    case cannotCreateExportSession
    case exportFailed(String)

    var description: String {
        switch self {
        case .invalidArguments: return "Invalid arguments"
        case .missingVideoTrack: return "Input video has no video track"
        case .missingVideoAudioTrack: return "Input video has no audio track"
        case .missingBGMTrack: return "BGM file has no audio track"
        case .cannotCreateTrack(let t): return "Could not create composition track: \(t)"
        case .cannotCreateExportSession: return "Could not create export session"
        case .exportFailed(let m): return "Export failed: \(m)"
        }
    }
}

func usage() -> Never {
    fputs("Usage: add_bgm_to_video.swift <input.mp4> <bgm.mp3> <output.mp4> [voiceVolume=1.0] [bgmVolume=0.10]\n", stderr)
    exit(2)
}

let args = CommandLine.arguments
if args.count < 4 || args.count > 6 { usage() }
let inputURL = URL(fileURLWithPath: args[1])
let bgmURL = URL(fileURLWithPath: args[2])
let outputURL = URL(fileURLWithPath: args[3])
let voiceVolume = Float(args.count >= 5 ? args[4] : "1.0") ?? 1.0
let bgmVolume = Float(args.count >= 6 ? args[5] : "0.10") ?? 0.10

try? FileManager.default.removeItem(at: outputURL)

let videoAsset = AVURLAsset(url: inputURL)
let bgmAsset = AVURLAsset(url: bgmURL)

guard let videoSrc = videoAsset.tracks(withMediaType: .video).first else { throw MixError.missingVideoTrack }
guard let voiceSrc = videoAsset.tracks(withMediaType: .audio).first else { throw MixError.missingVideoAudioTrack }
guard let bgmSrc = bgmAsset.tracks(withMediaType: .audio).first else { throw MixError.missingBGMTrack }

let duration = videoAsset.duration
let comp = AVMutableComposition()

guard let videoTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw MixError.cannotCreateTrack("video") }
guard let voiceTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw MixError.cannotCreateTrack("voice audio") }
guard let bgmTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw MixError.cannotCreateTrack("bgm audio") }

try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoSrc, at: .zero)
videoTrack.preferredTransform = videoSrc.preferredTransform
try voiceTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: voiceSrc, at: .zero)

var cursor = CMTime.zero
while cursor < duration {
    let remaining = CMTimeSubtract(duration, cursor)
    let chunk = min(remaining, bgmAsset.duration)
    try bgmTrack.insertTimeRange(CMTimeRange(start: .zero, duration: chunk), of: bgmSrc, at: cursor)
    cursor = CMTimeAdd(cursor, chunk)
    if chunk <= .zero { break }
}

let voiceParams = AVMutableAudioMixInputParameters(track: voiceTrack)
voiceParams.setVolume(voiceVolume, at: .zero)

let bgmParams = AVMutableAudioMixInputParameters(track: bgmTrack)
bgmParams.setVolume(bgmVolume, at: .zero)
let fadeIn = min(CMTime(seconds: 1.0, preferredTimescale: 600), duration)
bgmParams.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: bgmVolume, timeRange: CMTimeRange(start: .zero, duration: fadeIn))
let fadeDuration = CMTime(seconds: 1.5, preferredTimescale: 600)
let fadeStart = CMTimeSubtract(duration, fadeDuration)
if fadeStart.seconds.isFinite && fadeStart > .zero {
    bgmParams.setVolumeRamp(fromStartVolume: bgmVolume, toEndVolume: 0.0, timeRange: CMTimeRange(start: fadeStart, duration: fadeDuration))
}

let audioMix = AVMutableAudioMix()
audioMix.inputParameters = [voiceParams, bgmParams]

guard let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { throw MixError.cannotCreateExportSession }
export.outputURL = outputURL
export.outputFileType = .mp4
export.audioMix = audioMix
export.shouldOptimizeForNetworkUse = true

let group = DispatchGroup()
group.enter()
export.exportAsynchronously { group.leave() }
group.wait()

if export.status != .completed {
    let message = export.error?.localizedDescription ?? String(describing: export.status)
    throw MixError.exportFailed(message)
}
print(outputURL.path)
