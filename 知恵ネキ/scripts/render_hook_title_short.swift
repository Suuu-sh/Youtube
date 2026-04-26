#!/usr/bin/env swift
import Foundation
import AVFoundation
import AppKit
import CoreVideo

struct Manifest: Decodable {
    struct Scene: Decodable {
        let tag: String
        let title: String
        let subtitle: String
        let imageFile: String
        let highlightWords: [String]?
    }
    let width: Int
    let height: Int
    let fps: Int
    let badge: String
    let footer: String
    let scenes: [Scene]
    let segmentAudioFiles: [String]?
    let segmentVideos: [String]?
    let pauseSeconds: Double?
    let showCounter: Bool?
}

enum RenderError: Error { case invalidArguments, cannotLoadImage(String), cannotCreateWriter, cannotCreateInput, cannotCreateAdaptor, cannotCreateFrame, cannotCreateExportSession, missingVideoTrack }

func duration(_ url: URL) -> Double {
    let asset = AVURLAsset(url: url)
    let seconds = CMTimeGetSeconds(asset.duration)
    if seconds.isFinite, seconds > 0 { return seconds }
    return 0
}
func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double { min(max(v, a), b) }
func smooth(_ x: Double) -> Double { let t = clamp(x, 0, 1); return t*t*(3 - 2*t) }
func rounded(_ rect: NSRect, radius: CGFloat, fill: NSColor) { fill.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill() }
func paragraph(_ align: NSTextAlignment = .left, lineSpacing: CGFloat = 0) -> NSMutableParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = align; p.lineBreakMode = .byWordWrapping; p.lineSpacing = lineSpacing; return p }
func drawText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph(alignment, lineSpacing: lineSpacing)]
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
}
func drawOutlinedText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .center, lineSpacing: CGFloat = 5) {
    let style = paragraph(alignment, lineSpacing: lineSpacing)
    // Clean readable subtitle: shadow -> thick black stroke -> thin gold glow -> white fill.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.78)
    shadow.shadowOffset = NSSize(width: 0, height: -5)
    shadow.shadowBlurRadius = 16

    let base: [NSAttributedString.Key: Any] = [
        .font: font,
        .paragraphStyle: style
    ]
    var shadowAttrs = base
    shadowAttrs[.foregroundColor] = NSColor.black.withAlphaComponent(0.55)
    shadowAttrs[.shadow] = shadow
    NSString(string: text).draw(with: rect.offsetBy(dx: 0, dy: -2), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: shadowAttrs)

    var strokeAttrs = base
    strokeAttrs[.foregroundColor] = color
    strokeAttrs[.strokeColor] = NSColor.black.withAlphaComponent(0.96)
    strokeAttrs[.strokeWidth] = -12.0
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: strokeAttrs)

    var glowAttrs = base
    glowAttrs[.foregroundColor] = color
    glowAttrs[.strokeColor] = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.23, alpha: 0.65)
    glowAttrs[.strokeWidth] = -3.0
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: glowAttrs)

    var fillAttrs = base
    fillAttrs[.foregroundColor] = color
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: fillAttrs)
}
func highlightedAttributedString(_ text: String, base: [NSAttributedString.Key: Any], color: NSColor, highlightColor: NSColor, highlightWords: [String]) -> NSMutableAttributedString {
    let s = NSMutableAttributedString(string: text, attributes: base.merging([.foregroundColor: color]) { _, new in new })
    let ns = text as NSString
    for word in highlightWords where !word.isEmpty {
        var search = NSRange(location: 0, length: ns.length)
        while true {
            let r = ns.range(of: word, options: [], range: search)
            if r.location == NSNotFound { break }
            s.addAttribute(.foregroundColor, value: highlightColor, range: r)
            let next = r.location + r.length
            if next >= ns.length { break }
            search = NSRange(location: next, length: ns.length - next)
        }
    }
    return s
}
func drawOutlinedText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor, highlightWords: [String], alignment: NSTextAlignment = .center, lineSpacing: CGFloat = 5) {
    let style = paragraph(alignment, lineSpacing: lineSpacing)
    let highlight = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.22, alpha: 1)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.78)
    shadow.shadowOffset = NSSize(width: 0, height: -5)
    shadow.shadowBlurRadius = 16

    let base: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
    var shadowAttrs = base
    shadowAttrs[.foregroundColor] = NSColor.black.withAlphaComponent(0.55)
    shadowAttrs[.shadow] = shadow
    NSString(string: text).draw(with: rect.offsetBy(dx: 0, dy: -2), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: shadowAttrs)

    var strokeAttrs = base
    strokeAttrs[.strokeColor] = NSColor.black.withAlphaComponent(0.96)
    strokeAttrs[.strokeWidth] = -12.0
    highlightedAttributedString(text, base: strokeAttrs, color: color, highlightColor: highlight, highlightWords: highlightWords).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])

    var glowAttrs = base
    glowAttrs[.strokeColor] = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.23, alpha: 0.70)
    glowAttrs[.strokeWidth] = -3.0
    highlightedAttributedString(text, base: glowAttrs, color: color, highlightColor: highlight, highlightWords: highlightWords).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])

    highlightedAttributedString(text, base: base, color: color, highlightColor: highlight, highlightWords: highlightWords).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func drawSubtitleCard(_ rect: NSRect, progress: Double) {
    // Intentionally empty: no rectangle behind subtitles.
}
func drawCover(_ image: NSImage, in rect: NSRect, zoom: CGFloat = 1, offsetX: CGFloat = 0, offsetY: CGFloat = 0, fraction: CGFloat = 1) {
    let scale = max(rect.width / image.size.width, rect.height / image.size.height) * zoom
    let w = image.size.width * scale
    let h = image.size.height * scale
    image.draw(in: NSRect(x: rect.midX - w/2 + offsetX, y: rect.midY - h/2 + offsetY, width: w, height: h), from: .zero, operation: .sourceOver, fraction: fraction)
}
func loadImages(_ scenes: [Manifest.Scene]) throws -> [NSImage] {
    try scenes.map { scene in
        guard let img = NSImage(contentsOfFile: scene.imageFile) else { throw RenderError.cannotLoadImage(scene.imageFile) }
        return img
    }
}
func sceneDurations(_ manifest: Manifest, audioSeconds: Double) -> [Double] {
    let n = manifest.scenes.count
    let pause = manifest.pauseSeconds ?? 0.0
    let segments = manifest.segmentAudioFiles ?? manifest.segmentVideos
    if let files = segments, files.count == n {
        var ds = files.enumerated().map { idx, path in duration(URL(fileURLWithPath: path)) + (idx == files.count - 1 ? 0 : pause) }
        let sum = ds.reduce(0, +)
        if audioSeconds > sum, !ds.isEmpty { ds[ds.count - 1] += audioSeconds - sum }
        return ds
    }
    return Array(repeating: audioSeconds / Double(max(n, 1)), count: n)
}
func locateScene(frameTime: Double, durations: [Double]) -> (Int, Double) {
    var cursor = 0.0
    for (i, d) in durations.enumerated() {
        if frameTime < cursor + d { return (i, d > 0 ? clamp((frameTime - cursor) / d, 0, 1) : 0) }
        cursor += d
    }
    return (max(0, durations.count - 1), 1.0)
}

func makeFrame(manifest: Manifest, images: [NSImage], durations: [Double], frame: Int, audioSeconds: Double) -> CGImage? {
    let canvas = NSSize(width: manifest.width, height: manifest.height)
    let frameTime = Double(frame) / Double(manifest.fps)
    let (sceneIndex, local) = locateScene(frameTime: frameTime, durations: durations)
    let scene = manifest.scenes[min(sceneIndex, manifest.scenes.count - 1)]
    let image = images[min(sceneIndex, images.count - 1)]
    let out = NSImage(size: canvas)
    out.lockFocus()

    let z = CGFloat(1.035 + 0.018 * smooth(local))
    let panX = CGFloat((Double(sceneIndex % 3) - 1.0) * 16.0 * smooth(local))
    let panY = CGFloat(0.0 + (Double((sceneIndex + 1) % 3) - 1.0) * 6.0 * smooth(local))
    drawCover(image, in: NSRect(origin: .zero, size: canvas), zoom: z, offsetX: panX, offsetY: panY)

    // Keep the image natural: no top/bottom black veil and no center spotlight/band.
    NSColor.black.withAlphaComponent(0.015).setFill(); NSRect(origin: .zero, size: canvas).fill()

    let gold = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.28, alpha: 1)
    // Compact top information block. Keep badge, tag, and title visually connected.
    // top badge removed

    // No top progress bar.
    if manifest.showCounter ?? false {
        drawText(String(format: "%02d/%02d", sceneIndex + 1, manifest.scenes.count), in: NSRect(x: canvas.width - 190, y: canvas.height - 153, width: 136, height: 38), font: .monospacedDigitSystemFont(ofSize: 28, weight: .heavy), color: .white, alignment: .right)
    }

    // top tag removed
    // top title removed

    let appear = smooth(min(local / 0.18, 1.0))
    let bounce = CGFloat(1.0 + 0.035 * sin(appear * .pi))
    let subBase = NSRect(x: 72, y: 640, width: canvas.width - 144, height: 300)
    let subRect = NSRect(
        x: subBase.midX - subBase.width * bounce / 2,
        y: subBase.midY - subBase.height * bounce / 2 + CGFloat((1.0 - appear) * -22.0),
        width: subBase.width * bounce,
        height: subBase.height * bounce
    )
    drawSubtitleCard(subRect, progress: local)
    let highlights = scene.highlightWords ?? []
    if sceneIndex == 0 {
        let coverRect = NSRect(x: 36, y: canvas.height * 0.40, width: canvas.width - 72, height: 440)
        if highlights.isEmpty {
            drawOutlinedText(scene.subtitle, in: coverRect, font: .systemFont(ofSize: 98, weight: .black), color: .white, alignment: .center, lineSpacing: 26)
        } else {
            drawOutlinedText(scene.subtitle, in: coverRect, font: .systemFont(ofSize: 98, weight: .black), color: .white, highlightWords: highlights, alignment: .center, lineSpacing: 26)
        }
    } else if highlights.isEmpty {
        drawOutlinedText(scene.subtitle, in: subRect, font: .systemFont(ofSize: 61, weight: .black), color: .white, alignment: .center, lineSpacing: 11)
    } else {
        drawOutlinedText(scene.subtitle, in: subRect, font: .systemFont(ofSize: 61, weight: .black), color: .white, highlightWords: highlights, alignment: .center, lineSpacing: 11)
    }

    // No bottom footer/hashtags.
    out.unlockFocus()
    return out.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

func makePixelBuffer(from cgImage: CGImage, size: CGSize, pool: CVPixelBufferPool) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
    guard let buffer = pixelBuffer else { return nil }
    CVPixelBufferLockBaseAddress(buffer, []); defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
    ctx.clear(CGRect(origin: .zero, size: size)); ctx.draw(cgImage, in: CGRect(origin: .zero, size: size)); return buffer
}
func writeVideo(manifest: Manifest, audioURL: URL, tempVideoURL: URL) throws {
    let audioSeconds = duration(audioURL) + 0.5
    let durations = sceneDurations(manifest, audioSeconds: duration(audioURL))
    let totalFrames = Int(ceil(audioSeconds * Double(manifest.fps)))
    let size = CGSize(width: manifest.width, height: manifest.height)
    let images = try loadImages(manifest.scenes)
    try? FileManager.default.removeItem(at: tempVideoURL)
    guard let writer = try? AVAssetWriter(outputURL: tempVideoURL, fileType: .mov) else { throw RenderError.cannotCreateWriter }
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: manifest.width, AVVideoHeightKey: manifest.height])
    input.expectsMediaDataInRealTime = false
    let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB), kCVPixelBufferWidthKey as String: manifest.width, kCVPixelBufferHeightKey as String: manifest.height, kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
    guard let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs) as AVAssetWriterInputPixelBufferAdaptor? else { throw RenderError.cannotCreateAdaptor }
    guard writer.canAdd(input) else { throw RenderError.cannotCreateInput }
    writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
    for i in 0..<totalFrames {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
        guard let cg = makeFrame(manifest: manifest, images: images, durations: durations, frame: i, audioSeconds: audioSeconds), let pool = adaptor.pixelBufferPool, let buf = makePixelBuffer(from: cg, size: size, pool: pool) else { throw RenderError.cannotCreateFrame }
        adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(manifest.fps)))
    }
    input.markAsFinished(); let group = DispatchGroup(); group.enter(); writer.finishWriting { group.leave() }; group.wait()
}
func mux(videoURL: URL, audioURL: URL, outputURL: URL) throws {
    try? FileManager.default.removeItem(at: outputURL)
    let comp = AVMutableComposition(); let vAsset = AVURLAsset(url: videoURL); let aAsset = AVURLAsset(url: audioURL)
    guard let vSrc = vAsset.tracks(withMediaType: .video).first else { throw RenderError.missingVideoTrack }
    let dur = vAsset.duration; let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    try vTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: vSrc, at: .zero); vTrack?.preferredTransform = vSrc.preferredTransform
    if let aSrc = aAsset.tracks(withMediaType: .audio).first { let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid); try aTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: min(aAsset.duration, dur)), of: aSrc, at: .zero) }
    guard let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { throw RenderError.cannotCreateExportSession }
    export.outputURL = outputURL; export.outputFileType = .mp4; export.shouldOptimizeForNetworkUse = true
    let group = DispatchGroup(); group.enter(); export.exportAsynchronously { group.leave() }; group.wait(); if let error = export.error { throw error }
}

let args = CommandLine.arguments
if args.count != 4 { fputs("Usage: render_reference_clean_short.swift <manifest.json> <audio.m4a> <output.mp4>\n", stderr); throw RenderError.invalidArguments }
let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let tmp = URL(fileURLWithPath: args[3] + ".tmp.mov")
try writeVideo(manifest: manifest, audioURL: URL(fileURLWithPath: args[2]), tempVideoURL: tmp)
try mux(videoURL: tmp, audioURL: URL(fileURLWithPath: args[2]), outputURL: URL(fileURLWithPath: args[3]))
try? FileManager.default.removeItem(at: tmp)
