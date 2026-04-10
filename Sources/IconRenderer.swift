import Cocoa

enum IconRenderer {
    static let claudeColor = NSColor(red: 0.851, green: 0.467, blue: 0.337, alpha: 1.0)
    static let claudeLight = NSColor(red: 0.91, green: 0.55, blue: 0.43, alpha: 1.0)
    static let claudeDark = NSColor(red: 0.75, green: 0.38, blue: 0.27, alpha: 1.0)

    static func render(percentage: Int, hasSession: Bool) -> NSImage {
        let barWidth: CGFloat = 64
        let barHeight: CGFloat = 12
        let totalHeight: CGFloat = 22
        let radius: CGFloat = 3

        let remaining = hasSession ? max(100 - percentage, 0) : 0

        let image = NSImage(size: NSSize(width: barWidth, height: totalHeight), flipped: false) { rect in
            let yOffset = (rect.height - barHeight) / 2
            let barRect = CGRect(x: 0.5, y: yOffset, width: barWidth - 1, height: barHeight)

            // Background with subtle depth
            let bgPath = NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius)
            NSColor.labelColor.withAlphaComponent(0.06).setFill()
            bgPath.fill()

            // Progress fill with gradient
            if hasSession && remaining > 0 {
                let fillWidth = (barWidth - 1) * CGFloat(remaining) / 100.0
                let fillRect = CGRect(x: 0.5, y: yOffset, width: fillWidth, height: barHeight)

                // Clip to rounded rect
                NSGraphicsContext.saveGraphicsState()
                let clipPath = NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius)
                clipPath.addClip()

                // Gradient fill: lighter top to darker bottom
                let gradient = NSGradient(starting: claudeLight, ending: claudeColor)
                gradient?.draw(in: fillRect, angle: 270)

                NSGraphicsContext.restoreGraphicsState()
            }

            // Border
            let borderPath = NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius)
            let borderColor = hasSession ? claudeDark.withAlphaComponent(0.4) : NSColor.labelColor.withAlphaComponent(0.1)
            borderColor.setStroke()
            borderPath.lineWidth = 0.5
            borderPath.stroke()

            // Text shadow for readability
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
            shadow.shadowOffset = NSSize(width: 0, height: -0.5)
            shadow.shadowBlurRadius = 1

            // "session" — left
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 7.5, weight: .semibold),
                .foregroundColor: NSColor.white,
                .shadow: shadow
            ]
            let labelText = "session" as NSString
            let labelSize = labelText.size(withAttributes: labelAttrs)
            labelText.draw(
                at: NSPoint(x: 6, y: yOffset + (barHeight - labelSize.height) / 2),
                withAttributes: labelAttrs
            )

            // Percentage — right
            let pctText = hasSession ? "\(remaining)%" : "–"
            let pctAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 7.5, weight: .bold),
                .foregroundColor: NSColor.white,
                .shadow: shadow
            ]
            let pctSize = (pctText as NSString).size(withAttributes: pctAttrs)
            (pctText as NSString).draw(
                at: NSPoint(x: barWidth - pctSize.width - 5, y: yOffset + (barHeight - pctSize.height) / 2),
                withAttributes: pctAttrs
            )

            return true
        }

        image.isTemplate = false
        return image
    }
}
