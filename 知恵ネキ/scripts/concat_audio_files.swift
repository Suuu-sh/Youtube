#!/usr/bin/env swift
import Foundation
import AVFoundation

enum ConcatError: Error {
    case invalidArguments
    case missingAudioTrack(String)
    case cannotCreateExportSession
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    fputs("Usage: concat_audio_files.swift <output.m4a> <pauseSeconds> <input1> <input2> ...\n", stderr)
    throw ConcatError.invalidArguments
}

let outputURL = URL(fileURLWithPath: args[1])
let pauseSeconds = Double(args[2]) ?? 0.10
let inputURLs = args.dropFirst(3).map { URL(fileURLWithPath: $0) }
try? FileManager.default.removeItem(at: outputURL)

let composition = AVMutableComposition()
guard let outputTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
    throw ConcatError.cannotCreateExportSession
}

var cursor = CMTime.zero
let pause = CMTime(seconds: pauseSeconds, preferredTimescale: 600)
for (index, url) in inputURLs.enumerated() {
    let asset = AVURLAsset(url: url)
    guard let track = asset.tracks(withMediaType: .audio).first else {
        throw ConcatError.missingAudioTrack(url.path)
    }
    let duration = asset.duration
    try outputTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: cursor)
    cursor = cursor + duration
    if index != inputURLs.count - 1 { cursor = cursor + pause }
}

guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
    throw ConcatError.cannotCreateExportSession
}
export.outputURL = outputURL
export.outputFileType = .m4a
export.shouldOptimizeForNetworkUse = true
let group = DispatchGroup(); group.enter()
export.exportAsynchronously { group.leave() }
group.wait()
if let error = export.error { throw error }
