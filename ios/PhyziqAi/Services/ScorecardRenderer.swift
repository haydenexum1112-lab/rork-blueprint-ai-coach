import UIKit

/// Renders the shareable physique scorecard — a 9:16 (1080×1920) story image
/// with the physique score in a progress ring, top muscle-group ratings as
/// bars, and PhyziqAi branding. Uses the app's light blueprint theme.
///
/// `hideScore` produces the "challenge" teaser variant: the score shows as
/// "?" and region bars are de-emphasized so friends have to scan to see it.
enum ScorecardRenderer {

    struct Content {
        let score: Int
        /// Region name + 0–100 value, already sorted with the best first.
        let regions: [(name: String, value: Int)]
        let hideScore: Bool
        let challenge: Bool
    }

    // 9:16 story canvas.
    private static let size = CGSize(width: 1080, height: 1920)

    // Theme colors (mirrors Theme.swift).
    private static let bg = UIColor(red: 245 / 255, green: 248 / 255, blue: 252 / 255, alpha: 1)
    private static let surface = UIColor.white
    private static let surfaceHi = UIColor(red: 235 / 255, green: 242 / 255, blue: 250 / 255, alpha: 1)
    private static let accent = UIColor(red: 0 / 255, green: 178 / 255, blue: 224 / 255, alpha: 1)
    private static let accentDeep = UIColor(red: 0 / 255, green: 124 / 255, blue: 161 / 255, alpha: 1)
    private static let ink = UIColor(red: 15 / 255, green: 22 / 255, blue: 31 / 255, alpha: 1)
    private static let secondary = UIColor(red: 85 / 255, green: 100 / 255, blue: 118 / 255, alpha: 1)
    private static let warning = UIColor(red: 217 / 255, green: 142 / 255, blue: 26 / 255, alpha: 1)

    private static let ringCenter = CGPoint(x: 540, y: 850)
    private static let ringRadius: CGFloat = 280
    private static let ringWidth: CGFloat = 46

    static func render(_ content: Content) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            drawBackground(cg)
            drawHeader()
            drawHeadline(challenge: content.challenge)
            drawRingBackground(cg)
            drawRing(cg, score: content.score, hidden: content.hideScore)
            drawRegions(cg, regions: content.regions, hidden: content.hideScore)
            drawFooter(cg)
        }
    }

    // MARK: - Layers

    private static func drawBackground(_ cg: CGContext) {
        bg.setFill()
        cg.fill(CGRect(origin: .zero, size: size))

        // Blueprint grid.
        let grid = UIBezierPath()
        grid.lineWidth = 1.5
        accentDeep.withAlphaComponent(0.06).setStroke()
        var x: CGFloat = 90
        while x < size.width {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            x += 90
        }
        var y: CGFloat = 90
        while y < size.height {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
            y += 90
        }
        grid.stroke()

        // Faint dashed target circles behind the ring.
        accent.withAlphaComponent(0.16).setStroke()
        for radius in [ringRadius + 90, ringRadius + 150] {
            let circle = UIBezierPath(
                arcCenter: ringCenter,
                radius: radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            circle.setLineDash([5, 16], count: 2, phase: 0)
            circle.lineWidth = 2
            circle.stroke()
        }
    }

    private static func drawHeader() {
        drawText(
            "PHYZIQAI",
            font: roundedFont(62, .heavy),
            color: ink,
            topY: 140,
            kern: 16
        )
        drawText(
            "PHYSIQUE SCORECARD",
            font: heavyFont(30),
            color: accent,
            topY: 226,
            kern: 9
        )
    }

    private static func drawHeadline(challenge: Bool) {
        drawText(
            challenge ? "THINK YOU CAN BEAT ME?" : "MY PHYSIQUE SCORE",
            font: roundedFont(58, .heavy),
            color: ink,
            topY: 392,
            kern: 2
        )
    }

    private static func drawRingBackground(_ cg: CGContext) {
        // Dashed circles drawn here already; add the solid track + inner face.
        surfaceHi.setStroke()
        let track = UIBezierPath(
            arcCenter: ringCenter,
            radius: ringRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        track.lineWidth = ringWidth
        track.stroke()

        surface.setFill()
        cg.fillEllipse(
            in: CGRect(
                x: ringCenter.x - ringRadius + ringWidth / 2,
                y: ringCenter.y - ringRadius + ringWidth / 2,
                width: (ringRadius - ringWidth / 2) * 2,
                height: (ringRadius - ringWidth / 2) * 2
            )
        )
    }

    private static func drawRing(_ cg: CGContext, score: Int, hidden: Bool) {
        if hidden {
            drawText(
                "?",
                font: roundedFont(250, .black),
                color: accentDeep,
                topY: ringCenter.y - 155
            )
            drawText(
                "SCAN TO REVEAL",
                font: heavyFont(34),
                color: secondary,
                topY: ringCenter.y + 120,
                kern: 6
            )
            return
        }

        let clamped = CGFloat(min(max(score, 0), 100)) / 100
        if clamped > 0 {
            let progress = UIBezierPath(
                arcCenter: ringCenter,
                radius: ringRadius,
                startAngle: -.pi / 2,
                endAngle: -.pi / 2 + .pi * 2 * clamped,
                clockwise: true
            )
            accent.setStroke()
            progress.lineWidth = ringWidth
            progress.lineCapStyle = .round
            progress.stroke()
        }

        drawText(
            "\(score)",
            font: roundedFont(215, .black),
            color: ink,
            topY: ringCenter.y - 145
        )
        drawText(
            "/ 100",
            font: heavyFont(46),
            color: secondary,
            topY: ringCenter.y + 96
        )
    }

    private static func drawRegions(_ cg: CGContext, regions: [(name: String, value: Int)], hidden: Bool) {
        drawText(
            hidden ? "MUSCLE RATINGS" : "TOP MUSCLE RATINGS",
            font: heavyFont(30),
            color: accent,
            topY: 1330,
            kern: 8
        )

        let barX: CGFloat = 130
        let barWidth = size.width - barX * 2
        var y: CGFloat = 1420

        for region in regions.prefix(3) {
            let displayName = region.name.capitalized
            drawText(
                displayName,
                font: semiboldFont(36),
                color: ink,
                topY: y,
                alignment: .left,
                maxWidth: barWidth - 140,
                offsetX: barX
            )
            drawText(
                hidden ? "?" : "\(region.value)",
                font: roundedFont(38, .black),
                color: hidden ? secondary : ink,
                topY: y,
                alignment: .right,
                maxWidth: 130,
                offsetX: size.width - 130 - 130
            )

            let barY = y + 64
            let track = UIBezierPath(roundedRect: CGRect(x: barX, y: barY, width: barWidth, height: 22), cornerRadius: 11)
            surfaceHi.setFill()
            track.fill()

            let fillFraction: CGFloat = hidden ? 0.65 : CGFloat(min(max(region.value, 0), 100)) / 100
            let fillColor: UIColor = hidden
                ? accent.withAlphaComponent(0.3)
                : (region.value >= 75 ? accent : (region.value >= 50 ? accentDeep : warning))
            if fillFraction > 0 {
                let fill = UIBezierPath(
                    roundedRect: CGRect(x: barX, y: barY, width: max(barWidth * fillFraction, 22), height: 22),
                    cornerRadius: 11
                )
                fillColor.setFill()
                fill.fill()
            }

            y += 130
        }
    }

    private static func drawFooter(_ cg: CGContext) {
        let divider = UIBezierPath()
        divider.move(to: CGPoint(x: 140, y: 1748))
        divider.addLine(to: CGPoint(x: size.width - 140, y: 1748))
        divider.lineWidth = 3
        accent.withAlphaComponent(0.3).setStroke()
        divider.stroke()

        drawText(
            "SCAN YOURS AT PHYZIQAI",
            font: heavyFont(42),
            color: accentDeep,
            topY: 1790,
            kern: 5
        )
    }

    // MARK: - Text & font helpers

    private static func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        topY: CGFloat,
        kern: CGFloat = 0,
        alignment: NSTextAlignment = .center,
        maxWidth: CGFloat = size.width - 120,
        offsetX: CGFloat = 60
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: kern,
            .paragraphStyle: paragraph,
        ]
        let line = text as NSString
        let bounds = line.size(withAttributes: attributes)
        let rect = CGRect(
            x: offsetX,
            y: topY,
            width: maxWidth,
            height: ceil(bounds.height) + 8
        )
        line.draw(in: rect, withAttributes: attributes)
    }

    private static func roundedFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func heavyFont(_ size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .heavy)
    }

    private static func semiboldFont(_ size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .semibold)
    }
}
