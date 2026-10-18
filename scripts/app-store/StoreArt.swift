// Renders App Store marketing art for CardLah! with CoreGraphics + CoreText.
//
//   swift scripts/app-store/StoreArt.swift screenshots <raw dir> <out dir>
//       Frames raw device captures (see `shots` below) on a cream background with a
//       headline and the mascot, at every iPhone size App Store Connect asks for.
//   swift scripts/app-store/StoreArt.swift preview-cards <out dir>
//       Intro/outro cards and caption banners (886×1920) for make_preview.sh.
//
// Colours mirror Theme/AppColors.swift and the mascot mirrors Theme/Mascot.swift.

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// MARK: - Content

struct Shot {
    let raw: String        // file in <raw dir>
    let headline: String   // **word** is drawn in the tint colour
    let subline: String
    let tint: String       // hex
    let mood: Mood
    let dark: Bool
}

let shots: [Shot] = [
    Shot(raw: "1-today.png", headline: "Never miss a **min-spend**",
         subline: "Every Apple Wallet tap logs itself, no typing needed.",
         tint: "2E6DFF", mood: .excited, dark: false),
    Shot(raw: "2-cards.png", headline: "Hit every **card goal**",
         subline: "See what's left to spend before each statement.",
         tint: "22C55E", mood: .happy, dark: false),
    Shot(raw: "3-recap.png", headline: "Know **where it went**",
         subline: "Daily, weekly and monthly recaps by category.",
         tint: "F97316", mood: .happy, dark: false),
    Shot(raw: "4-me.png", headline: "Keep your **streak** going",
         subline: "Daily streaks and badges make tracking fun.",
         tint: "E3A21A", mood: .excited, dark: false),
    Shot(raw: "5-today-dark.png", headline: "Lovely by **day or night**",
         subline: "Light and dark themes, plus three mascot colours.",
         tint: "7CA3FF", mood: .happy, dark: true),
]

/// Portrait sizes App Store Connect accepts: 6.9" (Dynamic Island large),
/// 6.5" (Face ID large) and 6.1" (Dynamic Island medium, required).
let sizes: [(name: String, w: Int, h: Int)] = [
    ("6.9in", 1320, 2868),
    ("6.5in", 1284, 2778),
    ("6.1in", 1206, 2622),
]

// MARK: - Helpers

func color(_ hex: String, _ a: CGFloat = 1) -> CGColor {
    let v = UInt32(hex, radix: 16)!
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let fontsDir = scriptDir.appendingPathComponent("../../CardPulse/Resources/Fonts").standardized

for file in ["Fredoka-Bold.ttf", "Fredoka-SemiBold.ttf", "Nunito-Bold.ttf", "Nunito-Black.ttf"] {
    CTFontManagerRegisterFontsForURL(fontsDir.appendingPathComponent(file) as CFURL, .process, nil)
}

func font(_ name: String, _ size: CGFloat) -> CTFont { CTFontCreateWithName(name as CFString, size, nil) }
let fredoka = "FredokaLight-Bold"
let nunitoBold = "NunitoExtraLight-Bold"
let nunitoBlack = "NunitoExtraLight-Black"

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func writePNG(_ ctx: CGContext, _ url: URL, opaque: Bool) {
    var image = ctx.makeImage()!
    if opaque {
        // App Store Connect rejects screenshots with an alpha channel.
        let flat = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                             bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        flat.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        image = flat.makeImage()!
    }
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(url.path)")
}

func loadImage(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

/// Draws `text` (with **emphasis** spans) wrapped in `rect`. CG coordinates (origin bottom-left).
/// Returns the height actually used.
@discardableResult
func drawText(_ ctx: CGContext, _ text: String, in rect: CGRect, font fontName: String, size: CGFloat,
              color base: CGColor, emphasis: CGColor? = nil, align: CTTextAlignment = .left,
              lineHeight: CGFloat = 1.05) -> CGFloat {
    let attributed = NSMutableAttributedString()
    var emphasised = false
    for part in text.components(separatedBy: "**") {
        let fg = emphasised ? (emphasis ?? base) : base
        attributed.append(NSAttributedString(string: part, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font(fontName, size),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): fg,
        ]))
        emphasised.toggle()
    }
    var alignment = align
    var multiple = lineHeight
    let style = withUnsafePointer(to: &alignment) { alignmentPtr in
        withUnsafePointer(to: &multiple) { multiplePtr in
            let settings = [
                CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: alignmentPtr),
                CTParagraphStyleSetting(spec: .lineHeightMultiple, valueSize: MemoryLayout<CGFloat>.size, value: multiplePtr),
            ]
            return CTParagraphStyleCreate(settings, settings.count)
        }
    }
    attributed.addAttribute(NSAttributedString.Key(kCTParagraphStyleAttributeName as String), value: style,
                            range: NSRange(location: 0, length: attributed.length))
    let setter = CTFramesetterCreateWithAttributedString(attributed)
    let fit = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil,
                                                          CGSize(width: rect.width, height: .greatestFiniteMagnitude), nil)
    // Anchor to the top of `rect`.
    let frameRect = CGRect(x: rect.minX, y: rect.maxY - ceil(fit.height), width: rect.width, height: ceil(fit.height))
    let frame = CTFramesetterCreateFrame(setter, CFRange(), CGPath(rect: frameRect, transform: nil), nil)
    CTFrameDraw(frame, ctx)
    return ceil(fit.height)
}

func roundedRect(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// MARK: - Mascot (port of Theme/Mascot.swift, gold palette)

enum Mood { case happy, excited }

/// Draws the mascot with its 140×132 canvas fitted to `width`, top-left at `origin` (CG coords: top edge y).
func drawMascot(_ ctx: CGContext, mood: Mood, topLeft origin: CGPoint, width: CGFloat) {
    let main = color("FFC93C"), edge = color("E3A21A"), back = color("2E6DFF"), ink = color("0A1428")
    let s = width / 140
    ctx.saveGState()
    // Switch to the mascot's y-down canvas.
    ctx.translateBy(x: origin.x, y: origin.y)
    ctx.scaleBy(x: s, y: -s)

    func fill(_ p: CGPath, _ c: CGColor) { ctx.addPath(p); ctx.setFillColor(c); ctx.fillPath() }
    func stroke(_ p: CGPath, _ c: CGColor, _ w: CGFloat) {
        ctx.addPath(p); ctx.setStrokeColor(c); ctx.setLineWidth(w); ctx.setLineCap(.round); ctx.strokePath()
    }
    func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        roundedRect(CGRect(x: x, y: y, width: w, height: h), r)
    }

    fill(CGPath(ellipseIn: CGRect(x: 34, y: 119, width: 72, height: 12), transform: nil), color("0A1428", 0.10))

    ctx.saveGState()
    ctx.translateBy(x: 79, y: 41); ctx.rotate(by: 14 * .pi / 180); ctx.translateBy(x: -79, y: -41)
    let backCard = rr(40, 12, 80, 56, 14)
    fill(backCard, back)
    ctx.addPath(backCard); ctx.clip()
    fill(CGPath(rect: CGRect(x: 40, y: 24, width: 80, height: 9), transform: nil), color("000000", 0.2))
    ctx.restoreGState()

    let arms = CGMutablePath()
    if mood == .excited {
        arms.move(to: CGPoint(x: 26, y: 66)); arms.addLine(to: CGPoint(x: 10, y: 44))
        arms.move(to: CGPoint(x: 114, y: 66)); arms.addLine(to: CGPoint(x: 130, y: 44))
    } else {
        arms.move(to: CGPoint(x: 24, y: 74)); arms.addLine(to: CGPoint(x: 12, y: 90))
        arms.move(to: CGPoint(x: 116, y: 74)); arms.addLine(to: CGPoint(x: 128, y: 90))
    }
    stroke(arms, edge, 11)

    fill(rr(46, 100, 13, 21, 6.5), ink)
    fill(rr(81, 100, 13, 21, 6.5), ink)
    fill(rr(20, 34, 100, 76, 24), edge)
    fill(rr(20, 28, 100, 76, 24), main)

    fill(rr(30, 37, 19, 14, 4), color("FFF1C2"))
    stroke(rr(31, 38, 17, 12, 3), edge, 2)
    let chipLines = CGMutablePath()
    chipLines.move(to: CGPoint(x: 30, y: 44)); chipLines.addLine(to: CGPoint(x: 49, y: 44))
    chipLines.move(to: CGPoint(x: 39.5, y: 37)); chipLines.addLine(to: CGPoint(x: 39.5, y: 51))
    stroke(chipLines, edge, 1.6)

    let waves = CGMutablePath()
    waves.move(to: CGPoint(x: 98, y: 38)); waves.addQuadCurve(to: CGPoint(x: 98, y: 48), control: CGPoint(x: 102, y: 43))
    waves.move(to: CGPoint(x: 104, y: 35)); waves.addQuadCurve(to: CGPoint(x: 104, y: 51), control: CGPoint(x: 110, y: 43))
    stroke(waves, color("FFFFFF", 0.75), 3)

    for cx in [52.0, 88.0] as [CGFloat] {
        let eye = CGMutablePath()
        eye.move(to: CGPoint(x: cx - 8, y: 73)); eye.addQuadCurve(to: CGPoint(x: cx + 8, y: 73), control: CGPoint(x: cx, y: 62))
        stroke(eye, ink, 4.5)
    }
    fill(CGPath(ellipseIn: CGRect(x: 30, y: 80.5, width: 14, height: 9), transform: nil), color("FF7A9A", 0.55))
    fill(CGPath(ellipseIn: CGRect(x: 96, y: 80.5, width: 14, height: 9), transform: nil), color("FF7A9A", 0.55))

    let mouth = CGMutablePath()
    if mood == .excited {
        mouth.move(to: CGPoint(x: 56, y: 82)); mouth.addLine(to: CGPoint(x: 84, y: 82))
        mouth.addQuadCurve(to: CGPoint(x: 70, y: 99), control: CGPoint(x: 82, y: 99))
        mouth.addQuadCurve(to: CGPoint(x: 56, y: 82), control: CGPoint(x: 58, y: 99))
        mouth.closeSubpath()
        fill(mouth, ink)
        fill(CGPath(ellipseIn: CGRect(x: 63, y: 90.6, width: 14, height: 6.8), transform: nil), color("FF6B8B"))
    } else {
        mouth.move(to: CGPoint(x: 59, y: 84)); mouth.addLine(to: CGPoint(x: 81, y: 84))
        mouth.addQuadCurve(to: CGPoint(x: 70, y: 96), control: CGPoint(x: 79, y: 96))
        mouth.addQuadCurve(to: CGPoint(x: 59, y: 84), control: CGPoint(x: 61, y: 96))
        mouth.closeSubpath()
        fill(mouth, ink)
        fill(CGPath(ellipseIn: CGRect(x: 65, y: 89.4, width: 10, height: 5.2), transform: nil), color("FF6B8B"))
    }
    ctx.restoreGState()
}

// MARK: - Background

struct Palette {
    let bg: CGColor, ink: CGColor, secondary: CGColor
    static let light = Palette(bg: color("FFF7E8"), ink: color("0A1428"), secondary: color("5B6478"))
    static let dark = Palette(bg: color("0A1428"), ink: color("FFFFFF"), secondary: color("AAB3C5"))
}

func drawBackground(_ ctx: CGContext, w: CGFloat, h: CGFloat, tint: String, palette: Palette) {
    ctx.setFillColor(palette.bg)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    // Two soft tint glows: one behind the headline, one low behind the phone.
    for (center, radius, alpha) in [(CGPoint(x: w * 0.85, y: h * 0.86), w * 0.75, 0.22),
                                    (CGPoint(x: w * 0.1, y: h * 0.25), w * 0.9, 0.16)] {
        let g = CGGradient(colorsSpace: sRGB, colors: [color(tint, alpha), color(tint, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
    // A sprinkle of confetti in the design's accent colours.
    let confetti: [(CGFloat, CGFloat, CGFloat, String)] = [
        (0.06, 0.70, 0.010, "FFC93C"), (0.94, 0.64, 0.012, "2E6DFF"), (0.04, 0.42, 0.008, "F97316"),
        (0.96, 0.36, 0.009, "22C55E"), (0.08, 0.12, 0.011, "FF8FB8"), (0.93, 0.08, 0.010, "FFC93C"),
    ]
    for (x, y, r, hex) in confetti {
        ctx.setFillColor(color(hex, 0.9))
        ctx.fillEllipse(in: CGRect(x: w * x - w * r, y: h * y - w * r, width: w * r * 2, height: w * r * 2))
    }
}

// MARK: - Device frame

/// Chunky phone: ink bezel with a thicker bottom lip (like the app's cards) and a soft shadow.
func drawDevice(_ ctx: CGContext, screen: CGImage, screenRect: CGRect, dark: Bool) {
    let bezel = screenRect.width * 0.028
    let screenRadius = screenRect.width * 0.12
    let body = screenRect.insetBy(dx: -bezel, dy: -bezel)
    let bodyRadius = screenRadius + bezel
    let lip = screenRect.width * 0.018

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -screenRect.width * 0.03), blur: screenRect.width * 0.08,
                  color: color("0A1428", dark ? 0.6 : 0.22))
    ctx.addPath(roundedRect(body.offsetBy(dx: 0, dy: -lip), bodyRadius))
    ctx.setFillColor(dark ? color("26344F") : color("1E2A45"))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.addPath(roundedRect(body, bodyRadius))
    ctx.setFillColor(dark ? color("3A4A6B") : color("0A1428"))
    ctx.fillPath()

    ctx.saveGState()
    ctx.addPath(roundedRect(screenRect, screenRadius))
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(screen, in: screenRect)
    ctx.restoreGState()
}

// MARK: - Commands

func renderScreenshots(rawDir: URL, outDir: URL) {
    for size in sizes {
        let dir = outDir.appendingPathComponent(size.name)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (index, shot) in shots.enumerated() {
            guard let raw = loadImage(rawDir.appendingPathComponent(shot.raw)) else {
                print("skip \(shot.raw): not found in \(rawDir.path)")
                continue
            }
            let w = CGFloat(size.w), h = CGFloat(size.h)
            let palette = shot.dark ? Palette.dark : Palette.light
            let ctx = makeContext(size.w, size.h)
            drawBackground(ctx, w: w, h: h, tint: shot.tint, palette: palette)

            // Header: headline + subline on the left, mascot on the right.
            let margin = w * 0.07
            let mascotWidth = w * 0.27
            let textWidth = w - margin * 2 - mascotWidth - w * 0.02
            let top = h - h * 0.045
            let headlineHeight = drawText(ctx, shot.headline,
                                          in: CGRect(x: margin, y: 0, width: textWidth, height: top),
                                          font: fredoka, size: w * 0.083, color: palette.ink,
                                          emphasis: color(shot.tint), lineHeight: 0.95)
            let sublineHeight = drawText(ctx, shot.subline,
                     in: CGRect(x: margin, y: 0, width: textWidth, height: top - headlineHeight - w * 0.025),
                     font: nunitoBold, size: w * 0.038, color: palette.secondary, lineHeight: 1.1)
            drawMascot(ctx, mood: shot.mood, topLeft: CGPoint(x: w - margin - mascotWidth, y: top - w * 0.01),
                       width: mascotWidth)

            // Phone fills the rest, keeping the capture's aspect ratio.
            let textBottom = top - headlineHeight - w * 0.025 - sublineHeight - w * 0.06
            let headerBottom = min(h * 0.765, textBottom)
            let bottomMargin = h * 0.035
            let screenHeight = headerBottom - bottomMargin - w * 0.06
            let screenWidth = screenHeight * CGFloat(raw.width) / CGFloat(raw.height)
            let screenRect = CGRect(x: (w - screenWidth) / 2, y: bottomMargin + w * 0.035,
                                    width: screenWidth, height: screenHeight)
            drawDevice(ctx, screen: raw, screenRect: screenRect, dark: shot.dark)

            writePNG(ctx, dir.appendingPathComponent(String(format: "%02d-%@", index + 1, shot.raw)), opaque: true)
        }
    }
}

/// Caption banners overlaid on the preview, in order. Keep them short: previews play muted.
let previewCaptions = [
    "Taps log **themselves**",
    "Hit every **card goal**",
    "See **where it went**",
    "Keep your **streak** going",
]

func renderPreviewCards(outDir: URL) {
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let w: CGFloat = 886, h: CGFloat = 1920

    // Intro and outro: full-frame cards.
    for (name, title, sub, mood) in [
        ("intro", "Track every **tap**", "Apple Wallet spending, sorted.", Mood.excited),
        ("outro", "CardLah**!**", "Credit card goals, made fun.", Mood.happy),
    ] {
        let ctx = makeContext(Int(w), Int(h))
        drawBackground(ctx, w: w, h: h, tint: "2E6DFF", palette: .light)
        let mascotWidth = w * 0.58
        drawMascot(ctx, mood: mood, topLeft: CGPoint(x: (w - mascotWidth) / 2, y: h * 0.72), width: mascotWidth)
        let used = drawText(ctx, title, in: CGRect(x: w * 0.08, y: 0, width: w * 0.84, height: h * 0.40),
                            font: fredoka, size: w * 0.115, color: Palette.light.ink, emphasis: color("2E6DFF"),
                            align: .center, lineHeight: 0.95)
        drawText(ctx, sub, in: CGRect(x: w * 0.08, y: 0, width: w * 0.84, height: h * 0.40 - used - 24),
                 font: nunitoBold, size: w * 0.055, color: Palette.light.secondary, align: .center)
        writePNG(ctx, outDir.appendingPathComponent("\(name).png"), opaque: true)
    }

    // Caption banners: transparent PNGs with a chunky pill just above the tab bar, so screen titles stay visible.
    for (index, caption) in previewCaptions.enumerated() {
        let ctx = makeContext(Int(w), Int(h))
        let pill = CGRect(x: w * 0.06, y: h * 0.13, width: w * 0.88, height: h * 0.085)
        ctx.addPath(roundedRect(pill.offsetBy(dx: 0, dy: -10), pill.height / 2))
        ctx.setFillColor(color("1E4FD6"))
        ctx.fillPath()
        ctx.addPath(roundedRect(pill, pill.height / 2))
        ctx.setFillColor(color("2E6DFF"))
        ctx.fillPath()
        let size = w * 0.068
        drawText(ctx, caption.replacingOccurrences(of: "**", with: ""),
                 in: CGRect(x: pill.minX + 24, y: 0, width: pill.width - 48,
                            height: pill.midY + size * 0.62),
                 font: fredoka, size: size, color: color("FFFFFF"), align: .center)
        writePNG(ctx, outDir.appendingPathComponent(String(format: "caption-%d.png", index + 1)), opaque: false)
    }
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "screenshots" where args.count == 4:
    renderScreenshots(rawDir: URL(fileURLWithPath: args[2]), outDir: URL(fileURLWithPath: args[3]))
case "preview-cards" where args.count == 3:
    renderPreviewCards(outDir: URL(fileURLWithPath: args[2]))
default:
    print("usage: StoreArt.swift screenshots <raw dir> <out dir> | preview-cards <out dir>")
    exit(1)
}
