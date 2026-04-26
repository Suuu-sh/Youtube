#!/usr/bin/env swift
import Foundation
import AppKit

struct Manifest: Decodable {
    struct Scene: Decodable { let title: String; let body: String; let tag: String }
    let width: Int
    let height: Int
    let scenes: [Scene]
}

func paragraph(_ alignment: NSTextAlignment = .center) -> NSMutableParagraphStyle {
    let p = NSMutableParagraphStyle(); p.alignment = alignment; p.lineBreakMode = .byWordWrapping; return p
}
func drawText(_ text: String, _ rect: NSRect, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor, _ alignment: NSTextAlignment = .center) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph(alignment)]
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
}
func rounded(_ rect: NSRect, _ radius: CGFloat, _ color: NSColor) { color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill() }
func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: NSColor) { color.setFill(); NSBezierPath(ovalIn: NSRect(x: x-r, y: y-r, width: r*2, height: r*2)).fill() }
func line(_ a: CGPoint, _ b: CGPoint, _ width: CGFloat, _ color: NSColor) { color.setStroke(); let p=NSBezierPath(); p.lineWidth=width; p.move(to:a); p.line(to:b); p.stroke() }
func person(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat, _ color: NSColor, _ mood: String = "") {
    circle(x, y + 135*scale, 42*scale, NSColor(calibratedRed: 0.92, green: 0.72, blue: 0.55, alpha: 1))
    rounded(NSRect(x: x-58*scale, y: y-5*scale, width: 116*scale, height: 125*scale), 34*scale, color)
    line(CGPoint(x:x-48*scale,y:y+58*scale), CGPoint(x:x-102*scale,y:y-40*scale), 14*scale, color)
    line(CGPoint(x:x+48*scale,y:y+58*scale), CGPoint(x:x+102*scale,y:y-40*scale), 14*scale, color)
    line(CGPoint(x:x-30*scale,y:y), CGPoint(x:x-45*scale,y:y-98*scale), 18*scale, color)
    line(CGPoint(x:x+30*scale,y:y), CGPoint(x:x+45*scale,y:y-98*scale), 18*scale, color)
    NSColor.black.withAlphaComponent(0.65).setStroke(); let mouth=NSBezierPath(); mouth.lineWidth=3*scale
    if mood == "sad" { mouth.move(to: CGPoint(x:x-16*scale,y:y+126*scale)); mouth.curve(to: CGPoint(x:x+16*scale,y:y+126*scale), controlPoint1: CGPoint(x:x-6*scale,y:y+136*scale), controlPoint2: CGPoint(x:x+6*scale,y:y+136*scale)) }
    else { mouth.move(to: CGPoint(x:x-16*scale,y:y+123*scale)); mouth.curve(to: CGPoint(x:x+16*scale,y:y+123*scale), controlPoint1: CGPoint(x:x-6*scale,y:y+113*scale), controlPoint2: CGPoint(x:x+6*scale,y:y+113*scale)) }
    mouth.stroke()
}
func iconCard(_ rect: NSRect, _ color: NSColor, _ symbol: String) {
    rounded(rect, 34, NSColor.white.withAlphaComponent(0.12)); rounded(rect.insetBy(dx: 4, dy: 4), 30, NSColor.black.withAlphaComponent(0.10))
    drawText(symbol, rect.insetBy(dx: 10, dy: rect.height*0.24), rect.height*0.34, .bold, color)
}
func save(_ image: NSImage, _ path: String) throws {
    let pixelW = Int(image.size.width)
    let pixelH = Int(image.size.height)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelW,
        pixelsHigh: pixelH,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return }
    rep.size = image.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero, operation: .sourceOver, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try data.write(to: URL(fileURLWithPath: path))
}

let manifestPath = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
let manifest = try JSONDecoder().decode(Manifest.self, from: data)
let W = CGFloat(manifest.width), H = CGFloat(manifest.height)
let gold = NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.24, alpha: 1)
let amber = NSColor(calibratedRed: 0.72, green: 0.45, blue: 0.17, alpha: 1)
let dark = NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.08, alpha: 1)
let blueBlack = NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.10, alpha: 1)

for (i, scene) in manifest.scenes.enumerated() {
    let image = NSImage(size: NSSize(width: W, height: H)); image.lockFocus()
    NSGradient(colors: [NSColor(calibratedRed: 0.95, green: 0.84, blue: 0.62, alpha: 1), NSColor(calibratedRed: 0.18, green: 0.14, blue: 0.10, alpha: 1), blueBlack])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: CGFloat(90 + (i % 5) * 8))
    // soft rays / depth
    for k in 0..<9 { line(CGPoint(x: W/2, y: H*0.72), CGPoint(x: CGFloat(k)*W/8, y: H), 5, gold.withAlphaComponent(0.10)) }
    for k in 0..<18 { circle(CGFloat((k*137 + i*43) % Int(W)), CGFloat((k*211 + i*73) % Int(H)), CGFloat(18 + (k%5)*13), NSColor.white.withAlphaComponent(0.035)) }

    let keyword = scene.title + scene.body + scene.tag
    if keyword.contains("ザイオンス") || keyword.contains("接触") || keyword.contains("見慣れ") {
        for k in 0..<5 { iconCard(NSRect(x: 110 + CGFloat(k%2)*420, y: 650 + CGFloat(k)*135, width: 310, height: 250), gold, "顔") }
        person(W*0.50, 430, 1.35, dark, "")
        circle(W*0.50, 610, 250, gold.withAlphaComponent(0.10))
    } else if keyword.contains("返報") || keyword.contains("Give") || keyword.contains("借り") || keyword.contains("見返り") {
        person(W*0.32, 500, 1.18, dark); person(W*0.68, 500, 1.18, NSColor(calibratedRed:0.20,green:0.16,blue:0.12,alpha:1))
        iconCard(NSRect(x: 365, y: 830, width: 350, height: 260), gold, "贈")
        line(CGPoint(x:400,y:760), CGPoint(x:690,y:760), 12, gold.withAlphaComponent(0.75)); line(CGPoint(x:690,y:720), CGPoint(x:400,y:720), 12, gold.withAlphaComponent(0.75))
    } else if keyword.contains("損") || keyword.contains("失う") || keyword.contains("不安") || keyword.contains("煽り") {
        person(W*0.50, 430, 1.35, dark, "sad")
        iconCard(NSRect(x: 90, y: 820, width: 360, height: 320), NSColor.red.withAlphaComponent(0.85), "損")
        iconCard(NSRect(x: 630, y: 870, width: 300, height: 240), gold, "得")
        line(CGPoint(x:250,y:760), CGPoint(x:250,y:590), 18, NSColor.red.withAlphaComponent(0.75))
    } else if keyword.contains("ハロー") || keyword.contains("第一印象") || keyword.contains("長所") || keyword.contains("肩書") || keyword.contains("中身") {
        person(W*0.50, 500, 1.45, dark)
        circle(W*0.50, 780, 260, gold.withAlphaComponent(0.22)); circle(W*0.50, 780, 190, gold.withAlphaComponent(0.18))
        for k in 0..<5 { iconCard(NSRect(x: 95 + CGFloat(k%3)*310, y: 920 + CGFloat(k/3)*230, width: 250, height: 180), gold, "★") }
    } else if keyword.contains("希少") || keyword.contains("限定") || keyword.contains("期限") || keyword.contains("少ない") || keyword.contains("信用") {
        iconCard(NSRect(x: 315, y: 720, width: 450, height: 420), gold, "限定")
        for k in 0..<4 { person(160 + CGFloat(k)*250, 410 + CGFloat(k%2)*30, 0.9, dark) }
        circle(W*0.50, 930, 320, gold.withAlphaComponent(0.16))
    } else if keyword.contains("職場") || keyword.contains("会議") || keyword.contains("営業") || keyword.contains("SNS") {
        rounded(NSRect(x: 95, y: 470, width: 890, height: 360), 36, NSColor.black.withAlphaComponent(0.30))
        for k in 0..<5 { person(170 + CGFloat(k)*180, 520 + CGFloat(k%2)*35, 0.75, dark) }
        iconCard(NSRect(x: 315, y: 950, width: 450, height: 260), gold, "設計")
    } else {
        person(W*0.50, 450, 1.35, dark)
        for k in 0..<5 { iconCard(NSRect(x: 90 + CGFloat(k%2)*520, y: 810 + CGFloat(k/2)*190, width: 360, height: 160), gold, "心理") }
    }

    // Keep generated frame text-light; real Japanese text is rendered by code over the video.
    rounded(NSRect(x: 70, y: 1250, width: 940, height: 160), 42, NSColor.black.withAlphaComponent(0.20))
    drawText(scene.tag, NSRect(x: 100, y: 1330, width: 880, height: 44), 34, .heavy, gold)
    drawText(scene.title.replacingOccurrences(of: "\\n", with: " "), NSRect(x: 100, y: 1266, width: 880, height: 70), 42, .heavy, NSColor.white.withAlphaComponent(0.90))
    image.unlockFocus()
    try save(image, String(format: "%@/frame_%02d.png", outDir, i + 1))
}
print("created \(manifest.scenes.count) frames in \(outDir)")
