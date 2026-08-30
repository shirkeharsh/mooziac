import AppKit
import CoreGraphics
import CoreText

// ==============================================================================
// Mooziac Premium Retina DMG Background Generator
// Canvas: 680x480 points @ 2x Retina (1360x960 px)
// Features:
// 1. Draggable Finder Stage (Mooziac.app -> Applications) with aura glows & beam
// 2. 4-Step Visual Gatekeeper & Privacy/Security Onboarding Tutorial Panel
// ==============================================================================

let width: CGFloat = 680
let height: CGFloat = 480
let scale: CGFloat = 2.0

let pixelWidth = Int(width * scale)
let pixelHeight = Int(height * scale)

let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: pixelWidth,
    height: pixelHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create graphics context")
}

// Scale for Retina @2x
context.scaleBy(x: scale, y: scale)

// Enable high quality antialiasing
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.interpolationQuality = .high

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    return CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}

// Helper for flipped Y coordinates (y from top to bottom)
func fy(_ topY: CGFloat) -> CGFloat {
    return height - topY
}

// Helper to draw formatted multi-line text with CoreText
func drawText(
    _ text: String,
    in rect: CGRect,
    font: NSFont,
    color: CGColor,
    alignment: NSTextAlignment = .left,
    lineSpacing: CGFloat = 1.5
) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    style.lineSpacing = lineSpacing
    style.lineBreakMode = .byWordWrapping

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color) ?? NSColor.white,
        .paragraphStyle: style
    ]
    let attrStr = NSAttributedString(string: text, attributes: attrs)
    let framesetter = CTFramesetterCreateWithAttributedString(attrStr as CFAttributedString)
    let path = CGPath(rect: rect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attrStr.length), path, nil)
    CTFrameDraw(frame, context)
}

// ==============================================================================
// 1. Deep Obsidian Background Gradient
// ==============================================================================
let bgColors = [
    col(0.065, 0.075, 0.115, 1.0), // Top: Deep Slate Navy
    col(0.035, 0.035, 0.055, 1.0), // Mid: Obsidian
    col(0.012, 0.012, 0.020, 1.0)  // Bottom: Pure Midnight
] as CFArray
let bgLocations: [CGFloat] = [1.0, 0.45, 0.0]

if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
    context.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: width / 2, y: 0),
        end: CGPoint(x: width / 2, y: height),
        options: []
    )
}

// Ambient subtle diagonal highlight sheen across canvas
context.saveGState()
let sheenColors = [
    col(1.0, 1.0, 1.0, 0.0),
    col(1.0, 1.0, 1.0, 0.025)
] as CFArray
if let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 1.0]) {
    context.drawLinearGradient(
        sheenGrad,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: width, y: height),
        options: []
    )
}
context.restoreGState()

// Subtle Header Brand Title
let brandRect = CGRect(x: 0, y: height - 34, width: width, height: 22)
drawText(
    "MOOZIAC  ·  NATIVE macOS MUSIC PLAYER",
    in: brandRect,
    font: NSFont.systemFont(ofSize: 10, weight: .bold),
    color: col(0.0, 0.85, 1.0, 0.65),
    alignment: .center
)

// ==============================================================================
// 2. Drag & Drop Stage (Top Section)
// Left Dock: X = 180, Y_from_top = 135 -> fy(135) = 345
// Right Dock: X = 500, Y_from_top = 135 -> fy(135) = 345
// ==============================================================================
let leftCenter = CGPoint(x: 180, y: fy(135))
let rightCenter = CGPoint(x: 500, y: fy(135))

// Auras behind Docks
context.saveGState()
// Left Dock: Electric Cyan Glow
let cyanGlowColors = [
    col(0.0, 0.85, 1.0, 0.20),
    col(0.0, 0.65, 1.0, 0.08),
    col(0.0, 0.45, 1.0, 0.0)
] as CFArray
if let cyanGrad = CGGradient(colorsSpace: colorSpace, colors: cyanGlowColors, locations: [0.0, 0.45, 1.0]) {
    context.drawRadialGradient(
        cyanGrad,
        startCenter: leftCenter,
        startRadius: 0,
        endCenter: leftCenter,
        endRadius: 140,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

// Right Dock: Electric Violet Glow
let violetGlowColors = [
    col(0.68, 0.30, 1.0, 0.20),
    col(0.50, 0.20, 0.95, 0.08),
    col(0.35, 0.10, 0.85, 0.0)
] as CFArray
if let violetGrad = CGGradient(colorsSpace: colorSpace, colors: violetGlowColors, locations: [0.0, 0.45, 1.0]) {
    context.drawRadialGradient(
        violetGrad,
        startCenter: rightCenter,
        startRadius: 0,
        endCenter: rightCenter,
        endRadius: 140,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}
context.restoreGState()

// Left Dock: Solid Frosted Glass Plate
let cardSize: CGFloat = 136
let cornerRadius: CGFloat = 28
let leftCardRect = CGRect(
    x: leftCenter.x - cardSize / 2,
    y: leftCenter.y - cardSize / 2,
    width: cardSize,
    height: cardSize
)
let leftCardPath = CGPath(
    roundedRect: leftCardRect,
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)

context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -5),
    blur: 16,
    color: col(0.0, 0.0, 0.0, 0.45)
)
context.addPath(leftCardPath)
context.setFillColor(col(1.0, 1.0, 1.0, 0.04))
context.fillPath()
context.restoreGState()

// Specular Top Sheen Gradient
context.saveGState()
context.addPath(leftCardPath)
context.clip()
let leftGlassColors = [
    col(1.0, 1.0, 1.0, 0.02),
    col(1.0, 1.0, 1.0, 0.01),
    col(1.0, 1.0, 1.0, 0.08)
] as CFArray
if let glassGrad = CGGradient(colorsSpace: colorSpace, colors: leftGlassColors, locations: [0.0, 0.4, 1.0]) {
    context.drawLinearGradient(
        glassGrad,
        start: CGPoint(x: leftCardRect.midX, y: leftCardRect.minY),
        end: CGPoint(x: leftCardRect.midX, y: leftCardRect.maxY),
        options: []
    )
}
context.restoreGState()

// Specular Perimeter Border (Cyan Accent)
context.saveGState()
context.addPath(leftCardPath)
let leftBorderColors = [
    col(1.0, 1.0, 1.0, 0.04),
    col(1.0, 1.0, 1.0, 0.12),
    col(0.0, 0.9, 1.0, 0.45)
] as CFArray
if let borderGrad = CGGradient(colorsSpace: colorSpace, colors: leftBorderColors, locations: [0.0, 0.6, 1.0]) {
    context.setLineWidth(1.2)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
        borderGrad,
        start: CGPoint(x: leftCardRect.minX, y: leftCardRect.minY),
        end: CGPoint(x: leftCardRect.maxX, y: leftCardRect.maxY),
        options: []
    )
}
context.restoreGState()

// Right Dock: Dashed Drop-Target Slot
let rightCardRect = CGRect(
    x: rightCenter.x - cardSize / 2,
    y: rightCenter.y - cardSize / 2,
    width: cardSize,
    height: cardSize
)
let rightCardPath = CGPath(
    roundedRect: rightCardRect,
    cornerWidth: cornerRadius,
    cornerHeight: cornerRadius,
    transform: nil
)

context.saveGState()
context.addPath(rightCardPath)
context.setFillColor(col(1.0, 1.0, 1.0, 0.015))
context.fillPath()

let dashes: [CGFloat] = [8, 6]
context.setLineDash(phase: 0, lengths: dashes)
context.setLineWidth(1.6)
context.setLineCap(.round)
context.setLineJoin(.round)
context.addPath(rightCardPath)
context.setStrokeColor(col(0.70, 0.40, 1.0, 0.45))
context.strokePath()
context.restoreGState()

// Directional Arrow & Energy Beam
context.saveGState()
let arrowStartX: CGFloat = 265
let arrowEndX: CGFloat = 415
let arrowY: CGFloat = leftCenter.y

let arrowGradColors = [
    col(0.0, 0.90, 1.0, 0.95),  // Vibrant Cyan
    col(0.70, 0.40, 1.0, 0.95)   // Electric Violet
] as CFArray

if let arrowGrad = CGGradient(colorsSpace: colorSpace, colors: arrowGradColors, locations: [0.0, 1.0]) {
    // Outer glow behind arrow
    context.saveGState()
    context.setStrokeColor(col(0.2, 0.7, 1.0, 0.25))
    context.setLineWidth(8.0)
    context.setLineCap(.round)
    context.beginPath()
    context.move(to: CGPoint(x: arrowStartX, y: arrowY))
    context.addLine(to: CGPoint(x: arrowEndX - 2, y: arrowY))
    context.strokePath()
    context.restoreGState()

    // Core crisp gradient line
    context.saveGState()
    context.setLineWidth(3.2)
    context.setLineCap(.round)
    context.beginPath()
    context.move(to: CGPoint(x: arrowStartX, y: arrowY))
    context.addLine(to: CGPoint(x: arrowEndX - 2, y: arrowY))
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
        arrowGrad,
        start: CGPoint(x: arrowStartX, y: arrowY),
        end: CGPoint(x: arrowEndX, y: arrowY),
        options: []
    )
    context.restoreGState()
}

// Arrowhead (Chevron)
context.saveGState()
context.setStrokeColor(col(0.75, 0.45, 1.0, 0.98))
context.setLineWidth(3.2)
context.setLineCap(.round)
context.setLineJoin(.round)
context.setShadow(offset: .zero, blur: 8, color: col(0.70, 0.40, 1.0, 0.75))

context.beginPath()
let headLength: CGFloat = 12.0
let headHeight: CGFloat = 10.0
context.move(to: CGPoint(x: arrowEndX - headLength, y: arrowY - headHeight))
context.addLine(to: CGPoint(x: arrowEndX, y: arrowY))
context.addLine(to: CGPoint(x: arrowEndX - headLength, y: arrowY + headHeight))
context.strokePath()
context.restoreGState()

// "DRAG TO INSTALL" Floating Tag Pill above arrow
let tagPillRect = CGRect(x: 290, y: arrowY + 14, width: 100, height: 20)
let tagPillPath = CGPath(roundedRect: tagPillRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
context.saveGState()
context.addPath(tagPillPath)
context.setFillColor(col(0.05, 0.06, 0.10, 0.92))
context.fillPath()
context.addPath(tagPillPath)
context.setStrokeColor(col(0.0, 0.85, 1.0, 0.35))
context.setLineWidth(1.0)
context.strokePath()
drawText(
    "DRAG TO INSTALL",
    in: CGRect(x: 290, y: arrowY + 15, width: 100, height: 16),
    font: NSFont.systemFont(ofSize: 8.5, weight: .bold),
    color: col(0.0, 0.85, 1.0, 0.95),
    alignment: .center
)
context.restoreGState()

context.restoreGState()

// ==============================================================================
// 3. Bottom Section: 4-Step Gatekeeper & Security Onboarding Master Card
// Container: width 640, height 205, X = 20, Y = 16 (in CGContext coordinates)
// ==============================================================================
let masterX: CGFloat = 20
let masterY: CGFloat = 16
let masterW: CGFloat = 640
let masterH: CGFloat = 205

let masterRect = CGRect(x: masterX, y: masterY, width: masterW, height: masterH)
let masterPath = CGPath(roundedRect: masterRect, cornerWidth: 18, cornerHeight: 18, transform: nil)

// Master Card Backdrop & Shadow
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -4),
    blur: 20,
    color: col(0.0, 0.0, 0.0, 0.6)
)
context.addPath(masterPath)
context.setFillColor(col(0.04, 0.045, 0.075, 0.95))
context.fillPath()
context.restoreGState()

// Master Card Perimeter Border (Cyan to Violet Gradient)
context.saveGState()
context.addPath(masterPath)
let masterBorderColors = [
    col(0.0, 0.85, 1.0, 0.40),
    col(0.68, 0.30, 1.0, 0.40)
] as CFArray
if let masterBorderGrad = CGGradient(colorsSpace: colorSpace, colors: masterBorderColors, locations: [0.0, 1.0]) {
    context.setLineWidth(1.2)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
        masterBorderGrad,
        start: CGPoint(x: masterRect.minX, y: masterRect.maxY),
        end: CGPoint(x: masterRect.maxX, y: masterRect.minY),
        options: []
    )
}
context.restoreGState()

// Master Header Title & Badge
let headerTitleRect = CGRect(x: masterX + 16, y: masterY + masterH - 28, width: 400, height: 20)
drawText(
    "⚡ FIRST-TIME LAUNCH & GATEKEEPER GUIDE",
    in: headerTitleRect,
    font: NSFont.systemFont(ofSize: 11, weight: .bold),
    color: col(1.0, 1.0, 1.0, 0.95)
)

let headerBadgeRect = CGRect(x: masterX + masterW - 200, y: masterY + masterH - 26, width: 184, height: 16)
drawText(
    "macOS Sequoia · Sonoma · Ventura",
    in: headerBadgeRect,
    font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium),
    color: col(0.0, 0.85, 1.0, 0.80),
    alignment: .right
)

// Subtle Divider Line below header
context.saveGState()
context.setStrokeColor(col(1.0, 1.0, 1.0, 0.08))
context.setLineWidth(1.0)
context.beginPath()
context.move(to: CGPoint(x: masterX + 14, y: masterY + masterH - 34))
context.addLine(to: CGPoint(x: masterX + masterW - 14, y: masterY + masterH - 34))
context.strokePath()
context.restoreGState()

// ==============================================================================
// 4. The 4 Step Cards (Horizontal Grid)
// ==============================================================================
let cardW: CGFloat = 142
let cardH: CGFloat = 152
let cardMargin: CGFloat = 12
let cardY: CGFloat = masterY + 12

struct StepData {
    let number: String
    let icon: String
    let title: String
    let line1: String
    let line2: String
    let line3: String
    let accentCol: CGColor
}

let steps: [StepData] = [
    StepData(
        number: "1",
        icon: "📦",
        title: "Drag & Drop",
        line1: "Drag Mooziac.app",
        line2: "into Applications",
        line3: "folder shortcut above.",
        accentCol: col(0.0, 0.85, 1.0, 1.0)
    ),
    StepData(
        number: "2",
        icon: "🚀",
        title: "Open App",
        line1: "Open Mooziac from",
        line2: "Applications or Spotlight",
        line3: "to dock in menu bar.",
        accentCol: col(0.3, 0.65, 1.0, 1.0)
    ),
    StepData(
        number: "3",
        icon: "🛡️",
        title: "If macOS Blocks",
        line1: "Go to System Settings",
        line2: "→ Privacy & Security",
        line3: "→ Click 'Open Anyway'.",
        accentCol: col(0.95, 0.65, 0.15, 1.0) // Amber Alert
    ),
    StepData(
        number: "4",
        icon: "✅",
        title: "Confirm Open",
        line1: "Click 'Open Anyway'",
        line2: "on confirmation alert",
        line3: "to begin listening 🎵",
        accentCol: col(0.20, 0.88, 0.50, 1.0) // Neon Emerald
    )
]

for (i, step) in steps.enumerated() {
    let cX = masterX + cardMargin + CGFloat(i) * (cardW + 10)
    let cRect = CGRect(x: cX, y: cardY, width: cardW, height: cardH)
    let cPath = CGPath(roundedRect: cRect, cornerWidth: 12, cornerHeight: 12, transform: nil)

    // Card Fill
    context.saveGState()
    context.addPath(cPath)
    context.setFillColor(col(0.08, 0.085, 0.12, 0.70))
    context.fillPath()

    // Card Border
    context.addPath(cPath)
    if i == 2 { // Step 3 highlighted (Gatekeeper action)
        context.setStrokeColor(col(0.95, 0.65, 0.15, 0.50))
        context.setLineWidth(1.2)
    } else {
        context.setStrokeColor(col(1.0, 1.0, 1.0, 0.10))
        context.setLineWidth(1.0)
    }
    context.strokePath()
    context.restoreGState()

    // Step Number Pill Badge
    let pillRect = CGRect(x: cX + 10, y: cardY + cardH - 28, width: 22, height: 20)
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
    context.saveGState()
    context.addPath(pillPath)
    context.setFillColor(col(0.0, 0.0, 0.0, 0.6))
    context.fillPath()
    context.addPath(pillPath)
    context.setStrokeColor(step.accentCol)
    context.setLineWidth(1.0)
    context.strokePath()

    drawText(
        step.number,
        in: CGRect(x: cX + 10, y: cardY + cardH - 26, width: 22, height: 16),
        font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
        color: step.accentCol,
        alignment: .center
    )
    context.restoreGState()

    // Step Icon
    let iconRect = CGRect(x: cX + cardW - 32, y: cardY + cardH - 28, width: 22, height: 20)
    drawText(
        step.icon,
        in: iconRect,
        font: NSFont.systemFont(ofSize: 13),
        color: col(1.0, 1.0, 1.0, 1.0),
        alignment: .center
    )

    // Step Title
    let titleRect = CGRect(x: cX + 10, y: cardY + cardH - 56, width: cardW - 20, height: 20)
    drawText(
        step.title,
        in: titleRect,
        font: NSFont.systemFont(ofSize: 11.5, weight: .bold),
        color: col(1.0, 1.0, 1.0, 0.95)
    )

    // Step Body Lines
    let bodyRect = CGRect(x: cX + 10, y: cardY + 8, width: cardW - 20, height: 80)
    let bodyText = "\(step.line1)\n\(step.line2)\n\(step.line3)"
    let bodyColor = (i == 2) ? col(1.0, 0.90, 0.70, 0.90) : col(0.75, 0.78, 0.85, 0.85)

    drawText(
        bodyText,
        in: bodyRect,
        font: NSFont.systemFont(ofSize: 9.5, weight: (i == 2 ? .medium : .regular)),
        color: bodyColor,
        alignment: .left,
        lineSpacing: 3.0
    )
}

// ==============================================================================
// 5. Export to Retina 2x PNG Asset
// ==============================================================================
guard let cgImage = context.makeImage() else {
    fatalError("Failed to render CGImage from context")
}

let rep = NSBitmapImageRep(cgImage: cgImage)
rep.size = NSSize(width: width, height: height) // Establishes 2x Retina point resolution

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to generate PNG data")
}

let destinations = [
    "Resources/dmg_background.png",
    "Github/Resources/dmg_background.png",
    "mooziac/Resources/dmg_background.png"
]

for dest in destinations {
    let url = URL(fileURLWithPath: dest)
    let parent = url.deletingLastPathComponent()
    if FileManager.default.fileExists(atPath: parent.path) {
        do {
            try pngData.write(to: url)
            print("✅ Wrote Retina DMG background to \(dest)")
        } catch {
            print("⚠️ Could not write to \(dest): \(error)")
        }
    }
}

print("🎨 Successfully generated Premium Mooziac DMG background (\(Int(width))x\(Int(height)) @ 2x -> \(pixelWidth)x\(pixelHeight)px)")

