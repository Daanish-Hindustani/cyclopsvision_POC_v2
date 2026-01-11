import SwiftUI

/// DiagramOverlayView renders instructional diagram overlays on the camera feed
struct DiagramOverlayView: View {
    let overlay: OverlayInstruction
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Render each element
                ForEach(Array(overlay.elements.enumerated()), id: \.offset) { index, element in
                    renderElement(element, in: geometry.size)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func renderElement(_ element: OverlayElement, in size: CGSize) -> some View {
        switch element {
        case .circle(let circle):
            CircleOverlay(element: circle, containerSize: size)
        case .arrow(let arrow):
            ArrowOverlay(element: arrow, containerSize: size)
        case .label(let label):
            LabelOverlay(element: label, containerSize: size)
        case .rectangle(let rect):
            RectangleOverlay(element: rect, containerSize: size)
        }
    }
}

// MARK: - Circle Overlay

struct CircleOverlay: View {
    let element: CircleElement
    let containerSize: CGSize
    
    var body: some View {
        let center = CGPoint(
            x: element.center[0] * containerSize.width,
            y: element.center[1] * containerSize.height
        )
        let radius = element.radius * containerSize.width
        
        Circle()
            .stroke(
                Color(hex: element.color) ?? .yellow,
                style: StrokeStyle(
                    lineWidth: element.strokeWidth ?? 3,
                    dash: element.style == "dashed" ? [10, 5] : []
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(center)
            .overlay {
                // Animated pulse effect
                Circle()
                    .stroke(
                        Color(hex: element.color)?.opacity(0.3) ?? .yellow.opacity(0.3),
                        lineWidth: 2
                    )
                    .frame(width: radius * 2.2, height: radius * 2.2)
                    .position(center)
                    .modifier(PulseModifier())
            }
    }
}

// MARK: - Arrow Overlay

struct ArrowOverlay: View {
    let element: ArrowElement
    let containerSize: CGSize
    
    var body: some View {
        let from = CGPoint(
            x: element.from[0] * containerSize.width,
            y: element.from[1] * containerSize.height
        )
        let to = CGPoint(
            x: element.to[0] * containerSize.width,
            y: element.to[1] * containerSize.height
        )
        
        let color = Color(hex: element.color) ?? .red
        
        if element.style == "curved" {
            CurvedArrowShape(from: from, to: to)
                .stroke(color, style: StrokeStyle(
                    lineWidth: element.strokeWidth ?? 3,
                    lineCap: .round,
                    lineJoin: .round
                ))
                .overlay {
                    // Arrowhead
                    ArrowheadShape(at: to, direction: arrowDirection(from: from, to: to))
                        .fill(color)
                }
        } else {
            StraightArrowShape(from: from, to: to)
                .stroke(color, style: StrokeStyle(
                    lineWidth: element.strokeWidth ?? 3,
                    lineCap: .round,
                    lineJoin: .round
                ))
                .overlay {
                    ArrowheadShape(at: to, direction: arrowDirection(from: from, to: to))
                        .fill(color)
                }
        }
    }
    
    private func arrowDirection(from: CGPoint, to: CGPoint) -> CGFloat {
        atan2(to.y - from.y, to.x - from.x)
    }
}

struct StraightArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        return path
    }
}

struct CurvedArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        
        // Calculate control point for curve
        let midX = (from.x + to.x) / 2
        let midY = (from.y + to.y) / 2
        let dx = to.x - from.x
        let dy = to.y - from.y
        
        // Offset perpendicular to the line
        let offset: CGFloat = min(abs(dx), abs(dy)) * 0.3
        let controlPoint = CGPoint(
            x: midX - dy * 0.3,
            y: midY + dx * 0.3
        )
        
        path.addQuadCurve(to: to, control: controlPoint)
        return path
    }
}

struct ArrowheadShape: Shape {
    let at: CGPoint
    let direction: CGFloat
    let size: CGFloat = 15
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let angle1 = direction + .pi * 0.8
        let angle2 = direction - .pi * 0.8
        
        let point1 = CGPoint(
            x: at.x + cos(angle1) * size,
            y: at.y + sin(angle1) * size
        )
        let point2 = CGPoint(
            x: at.x + cos(angle2) * size,
            y: at.y + sin(angle2) * size
        )
        
        path.move(to: at)
        path.addLine(to: point1)
        path.addLine(to: point2)
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Label Overlay

struct LabelOverlay: View {
    let element: LabelElement
    let containerSize: CGSize
    
    var body: some View {
        let position = CGPoint(
            x: element.position[0] * containerSize.width,
            y: element.position[1] * containerSize.height
        )
        
        Text(element.text)
            .font(.system(size: CGFloat(element.fontSize ?? 14), weight: .semibold))
            .foregroundColor(Color(hex: element.color ?? "#FFFFFF") ?? .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: element.background ?? "#000000AA") ?? Color.black.opacity(0.7))
            )
            .position(position)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Rectangle Overlay

struct RectangleOverlay: View {
    let element: RectangleElement
    let containerSize: CGSize
    
    var body: some View {
        let origin = CGPoint(
            x: element.origin[0] * containerSize.width,
            y: element.origin[1] * containerSize.height
        )
        let size = CGSize(
            width: element.size[0] * containerSize.width,
            height: element.size[1] * containerSize.height
        )
        
        RoundedRectangle(cornerRadius: element.cornerRadius ?? 0)
            .stroke(
                Color(hex: element.color) ?? .green,
                lineWidth: element.strokeWidth ?? 2
            )
            .frame(width: size.width, height: size.height)
            .position(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }
}

// MARK: - Animations

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        var alpha: Double = 1.0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let length = hexSanitized.count
        
        switch length {
        case 6: // RGB
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8: // RGBA
            alpha = Double(rgb & 0x000000FF) / 255.0
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: alpha
            )
        default:
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        
        DiagramOverlayView(overlay: OverlayInstruction(
            overlayType: "diagram",
            audioText: "Rotate the wire clockwise",
            elements: [
                .circle(CircleElement(
                    type: "circle",
                    center: [0.5, 0.4],
                    radius: 0.1,
                    color: "#FFD700",
                    strokeWidth: 3,
                    style: "solid",
                    fill: nil
                )),
                .arrow(ArrowElement(
                    type: "arrow",
                    from: [0.3, 0.6],
                    to: [0.5, 0.45],
                    color: "#FF4444",
                    strokeWidth: 3,
                    style: "curved",
                    headStyle: "filled"
                )),
                .label(LabelElement(
                    type: "label",
                    position: [0.5, 0.25],
                    text: "Rotate clockwise",
                    fontSize: 16,
                    color: "#FFFFFF",
                    background: "#000000AA"
                ))
            ],
            durationSeconds: 5.0
        ))
    }
}
