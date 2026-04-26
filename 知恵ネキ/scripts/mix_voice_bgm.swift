#!/usr/bin/env swift
import Foundation
import AVFoundation

enum MixError: Error {
    case invalidArguments
    case missingVoiceTrack
    case missingBGMTrack
    case cannotCreateExportSession
}

let args = CommandLine.arguments
guard args.count == 6 else {
    fputs("Usage: mix_voice_bgm.swift <voice.m4a> <bgm.wav> <output.m4a> <voiceVolume> <bgmVolume>\n", stderr)
    throw MixError.invalidArguments
}
let voiceURL = URL(fileURLWithPath: args[1])
let bgmURL = URL(fileURLWithPath: args[2])
let outputURL = URL(fileURLWithPath: args[3])
let voiceVol = Float(args[4]) ?? 1.0
let bgmVol = Float(args[5]) ?? 0.12
try? FileManager.default.removeItem(at: outputURL)

let voiceAsset = AVURLAsset(url: voiceURL)
let bgmAsset = AVURLAsset(url: bgmURL)
guard let voiceSrc = voiceAsset.tracks(withMediaType: .audio).first else { throw MixError.missingVoiceTrack }
guard let bgmSrc = bgmAsset.tracks(withMediaType: .audio).first else { throw MixError.missingBGMTrack }
let duration = voiceAsset.duration

let comp = AVMutableComposition()
guard let voiceTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
      let bgmTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
    throw MixError.cannotCreateExportSession
}
try voiceTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: voiceSrc, at: .zero)
try bgmTrack.insertTimeRange(CMTimeRange(start: .zero, duration: min(duration, bgmAsset.duration)), of: bgmSrc, at: .zero)

let voiceParams = AVMutableAudioMixInputParameters(track: voiceTrack)
voiceParams.setVolume(voiceVol, at: .zero)
let bgmParams = AVMutableAudioMixInputParameters(track: bgmTrack)
bgmParams.setVolume(bgmVol, at: .zero)
bgmParams.setVolumeRamp(fromStartVolume: 0.0, toEndVolume: bgmVol, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 1.8, preferredTimescale: 600)))
let fadeStart = CMTimeSubtract(duration, CMTime(seconds: 2.0, preferredTimescale: 600))
if fadeStart.seconds.isFinite, fadeStart > .zero {
    bgmParams.setVolumeRamp(fromStartVolume: bgmVol, toEndVolume: 0.0, timeRange: CMTimeRange(start: fadeStart, duration: CMTime(seconds: 2.0, preferredTimescale: 600)))
}
let mix = AVMutableAudioMix()
mix.inputParameters = [voiceParams, bgmParams]

guard let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetAppleM4A) else { throw MixError.cannotCreateExportSession }
export.outputURL = outputURL
export.outputFileType = .m4a
export.audioMix = mix
export.shouldOptimizeForNetworkUse = true
let group = DispatchGroup(); group.enter()
export.exportAsynchronously { group.leave() }
group.wait()
if let error = export.error { throw error }
