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
    }
    let width: Int
    let height: Int
    let fps: Int
    let badge: String
    let footer: String
    let scenes: [Scene]
    let segmentVideos: [String]?
    let pauseSeconds: Double?
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
    let strokeAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .strokeColor: NSColor.black.withAlphaComponent(0.86),
        .strokeWidth: -7.5,
        .paragraphStyle: style
    ]
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: strokeAttrs)
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
    if let videos = manifest.segmentVideos, videos.count == n {
        var ds = videos.enumerated().map { idx, path in
            duration(URL(fileURLWithPath: path)) + (idx == videos.count - 1 ? 0 : pause)
        }
        let sum = ds.reduce(0, +)
        if audioSeconds > sum, !ds.isEmpty { ds[ds.count - 1] += audioSeconds - sum }
        return ds
    }
    return Array(repeating: audioSeconds / Double(max(n, 1)), count: n)
}
func locateScene(frameTime: Double, durations: [Double]) -> (Int, Double) {
    var cursor = 0.0
    for (i, d) in durations.enumerated() {
        if frameTime < cursor + d {
            let local = d > 0 ? (frameTime - cursor) / d : 0
            return (i, clamp(local, 0, 1))
        }
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

    let z = CGFloat(1.015 + 0.055 * smooth(local))
    let panX = CGFloat((Double(sceneIndex % 3) - 1.0) * 24.0 * smooth(local))
    let panY = CGFloat((Double((sceneIndex + 1) % 3) - 1.0) * 18.0 * smooth(local))
    drawCover(image, in: NSRect(origin: .zero, size: canvas), zoom: z, offsetX: panX, offsetY: panY)

    NSColor.black.withAlphaComponent(0.14).setFill(); NSRect(origin: .zero, size: canvas).fill()
    NSGradient(starting: NSColor.black.withAlphaComponent(0.86), ending: NSColor.black.withAlphaComponent(0.0))?.draw(in: NSRect(x: 0, y: canvas.height * 0.68, width: canvas.width, height: canvas.height * 0.32), angle: 90)
    NSGradient(starting: NSColor.black.withAlphaComponent(0.74), ending: NSColor.black.withAlphaComponent(0.0))?.draw(in: NSRect(x: 0, y: 0, width: canvas.width, height: canvas.height * 0.26), angle: -90)
    NSGradient(starting: NSColor.black.withAlphaComponent(0.58), ending: NSColor.black.withAlphaComponent(0.0))?.draw(in: NSRect(x: 0, y: canvas.height * 0.38, width: canvas.width, height: canvas.height * 0.24), angle: 0)

    let gold = NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.28, alpha: 1)
    rounded(NSRect(x: 48, y: canvas.height - 160, width: 470, height: 64), radius: 32, fill: NSColor.black.withAlphaComponent(0.64))
    drawText(manifest.badge, in: NSRect(x: 82, y: canvas.height - 144, width: 400, height: 34), font: .systemFont(ofSize: 29, weight: .heavy), color: gold)

    let progress = CGFloat(Double(sceneIndex + 1) / Double(max(manifest.scenes.count, 1)))
    rounded(NSRect(x: 48, y: canvas.height - 201, width: canvas.width - 96, height: 8), radius: 4, fill: NSColor.white.withAlphaComponent(0.22))
    rounded(NSRect(x: 48, y: canvas.height - 201, width: (canvas.width - 96) * progress, height: 8), radius: 4, fill: gold)
    drawText(String(format: "%02d/%02d", sceneIndex + 1, manifest.scenes.count), in: NSRect(x: canvas.width - 190, y: canvas.height - 153, width: 136, height: 38), font: .monospacedDigitSystemFont(ofSize: 28, weight: .heavy), color: .white, alignment: .right)

    drawText(scene.tag, in: NSRect(x: 64, y: canvas.height - 302, width: canvas.width - 128, height: 42), font: .systemFont(ofSize: 34, weight: .heavy), color: gold)
    drawText(scene.title, in: NSRect(x: 62, y: canvas.height - 364, width: canvas.width - 124, height: 62), font: .systemFont(ofSize: 48, weight: .heavy), color: .white)

    let subRect = NSRect(x: 62, y: canvas.height * 0.43, width: canvas.width - 124, height: 230)
    rounded(subRect.insetBy(dx: -18, dy: -14), radius: 34, fill: NSColor.black.withAlphaComponent(0.34))
    drawOutlinedText(scene.subtitle, in: subRect, font: .systemFont(ofSize: 57, weight: .heavy), color: .white, alignment: .center, lineSpacing: 8)

    drawText(manifest.footer, in: NSRect(x: 64, y: 62, width: canvas.width - 128, height: 32), font: .systemFont(ofSize: 24, weight: .bold), color: NSColor.white.withAlphaComponent(0.72), alignment: .center)

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
if args.count != 4 { fputs("Usage: render_reference_real_short.swift <manifest.json> <audio.m4a> <output.mp4>\n", stderr); throw RenderError.invalidArguments }
let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let tmp = URL(fileURLWithPath: args[3] + ".tmp.mov")
try writeVideo(manifest: manifest, audioURL: URL(fileURLWithPath: args[2]), tempVideoURL: tmp)
try mux(videoURL: tmp, audioURL: URL(fileURLWithPath: args[2]), outputURL: URL(fileURLWithPath: args[3]))
try? FileManager.default.removeItem(at: tmp)
