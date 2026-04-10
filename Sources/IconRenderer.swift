import Cocoa

enum IconRenderer {
    static let claudeColor = NSColor(red: 0.851, green: 0.467, blue: 0.337, alpha: 1.0)

    static func render(percentage: Int, hasSession: Bool) -> NSImage {
        let barWidth: CGFloat = 78
        let barHeight: CGFloat = 16
        let totalHeight: CGFloat = 22

        let remaining = hasSession ? max(100 - percentage, 0) : 0

        let image = NSImage(size: NSSize(width: barWidth, height: totalHeight), flipped: false) { rect in
            let yOffset = (rect.height - barHeight) / 2

            // Background
            let bgRect = CGRect(x: 0, y: yOffset, width: barWidth, height: barHeight)
            let bgPath = NSBezierPath(rect: bgRect)
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            bgPath.fill()

            // Progress fill — Claude color
            if hasSession && remaining > 0 {
                let fillWidth = barWidth * CGFloat(remaining) / 100.0
                let fillRect = CGRect(x: 0, y: yOffset, width: fillWidth, height: barHeight)
                let fillPath = NSBezierPath(rect: fillRect)
                claudeColor.setFill()
                fillPath.fill()
            }

            // Border
            let borderPath = NSBezierPath(rect: bgRect)
            let borderAlpha: CGFloat = hasSession ? 0.25 : 0.12
            NSColor.labelColor.withAlphaComponent(borderAlpha).setStroke()
            borderPath.lineWidth = 0.5
            borderPath.stroke()

            // "session" label — left side
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8.5, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let labelText = "session" as NSString
            let labelSize = labelText.size(withAttributes: labelAttrs)
            let labelPoint = NSPoint(
                x: 6,
                y: yOffset + (barHeight - labelSize.height) / 2
            )
            labelText.draw(at: labelPoint, withAttributes: labelAttrs)

            // Percentage — right side
            let pctText = hasSession ? "\(remaining)%" : "–"
            let pctAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let pctSize = (pctText as NSString).size(withAttributes: pctAttrs)
            let pctPoint = NSPoint(
                x: barWidth - pctSize.width - 5,
                y: yOffset + (barHeight - pctSize.height) / 2
            )
            (pctText as NSString).draw(at: pctPoint, withAttributes: pctAttrs)

            return true
        }

        image.isTemplate = false
        return image
    }
}
