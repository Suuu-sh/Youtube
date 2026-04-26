#!/usr/bin/env swift

import Foundation
import AppKit

enum PosterError: Error {
    case invalidArguments
    case cannotLoadImage
    case cannotEncode
}

let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("Usage: compose_zajonc_explainer_poster.swift <base-image.png> <output-poster.png>\n", stderr)
    throw PosterError.invalidArguments
}

let inputPath = args[1]
let outputPath = args[2]

guard let base = NSImage(contentsOfFile: inputPath) else {
    throw PosterError.cannotLoadImage
}

let canvas = NSSize(width: 1080, height: 1920)
let poster = NSImage(size: canvas)

func paragraph(_ alignment: NSTextAlignment = .left, _ lineSpacing: CGFloat = 0) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineBreakMode = .byWordWrapping
    style.lineSpacing = lineSpacing
    return style
}

func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor = .black,
    alignment: NSTextAlignment = .left,
    lineSpacing: CGFloat = 0
) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph(alignment, lineSpacing)
    ]
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
}

func rounded(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawCover(_ image: NSImage, in canvas: NSSize) {
    let scale = max(canvas.width / image.size.width, canvas.height / image.size.height)
    let w = image.size.width * scale
    let h = image.size.height * scale
    let rect = NSRect(x: (canvas.width - w) / 2, y: (canvas.height - h) / 2, width: w, height: h)
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

let ink = NSColor(calibratedRed: 0.07, green: 0.055, blue: 0.045, alpha: 1.0)
let brown = NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.18, alpha: 1.0)
let cream = NSColor(calibratedRed: 0.99, green: 0.94, blue: 0.84, alpha: 0.88)
let accent = NSColor(calibratedRed: 0.78, green: 0.53, blue: 0.29, alpha: 1.0)

poster.lockFocus()
drawCover(base, in: canvas)

// Subtle text-safe bands that still feel integrated with the generated image.
rounded(NSRect(x: 68, y: 1600, width: 944, height: 222), radius: 42, fill: cream)
rounded(NSRect(x: 64, y: 1588, width: 952, height: 6), radius: 3, fill: accent.withAlphaComponent(0.55))

drawText(
    "何度も見ると\n好きになる心理",
    in: NSRect(x: 100, y: 1658, width: 660, height: 128),
    font: .systemFont(ofSize: 56, weight: .heavy),
    color: ink,
    lineSpacing: 2
)
rounded(NSRect(x: 770, y: 1666, width: 188, height: 52), radius: 26, fill: accent.withAlphaComponent(0.22))
drawText(
    "ザイオンス効果",
    in: NSRect(x: 790, y: 1678, width: 150, height: 28),
    font: .systemFont(ofSize: 21, weight: .bold),
    color: brown,
    alignment: .center
)

let labels: [(String, String, CGFloat)] = [
    ("01", "初回は\nまだ警戒", 1204),
    ("02", "何度も見ると\n見慣れる", 860),
    ("03", "警戒心が下がり\n親近感が出る", 520)
]

for (num, text, y) in labels {
    rounded(NSRect(x: 690, y: y, width: 318, height: 126), radius: 28, fill: cream)
    drawText(num, in: NSRect(x: 720, y: y + 72, width: 54, height: 34), font: .monospacedDigitSystemFont(ofSize: 28, weight: .heavy), color: accent)
    drawText(text, in: NSRect(x: 780, y: y + 36, width: 190, height: 62), font: .systemFont(ofSize: 26, weight: .heavy), color: ink, lineSpacing: 3)
}

rounded(NSRect(x: 74, y: 106, width: 932, height: 132), radius: 40, fill: cream)
drawText(
    "接触頻度が、好意の強さを決める。",
    in: NSRect(x: 110, y: 148, width: 860, height: 48),
    font: .systemFont(ofSize: 40, weight: .heavy),
    color: ink,
    alignment: .center
)
drawText(
    "同じ情報でも「何度も見た」だけで、人は安心しやすい。",
    in: NSRect(x: 130, y: 118, width: 820, height: 24),
    font: .systemFont(ofSize: 19, weight: .semibold),
    color: brown,
    alignment: .center
)

poster.unlockFocus()

guard let cg = poster.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    throw PosterError.cannotEncode
}

let rep = NSBitmapImageRep(cgImage: cg)
guard let data = rep.representation(using: .png, properties: [:]) else {
    throw PosterError.cannotEncode
}

try data.write(to: URL(fileURLWithPath: outputPath))

