import SwiftUI
import Vision

struct SkeletonView: View {
    let bodyPose: VNHumanBodyPoseObservation
    
    // Normalized points from Vision are (0,0) bottom-left, (1,1) top-right.
    // SwiftUI coordinates are (0,0) top-left.
    // We must flip Y.
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Torso
                drawLine(path: &path, from: .neck, to: .root, geometry: geometry)
                drawLine(path: &path, from: .neck, to: .leftShoulder, geometry: geometry)
                drawLine(path: &path, from: .neck, to: .rightShoulder, geometry: geometry)
                drawLine(path: &path, from: .leftShoulder, to: .rightShoulder, geometry: geometry)
                drawLine(path: &path, from: .root, to: .leftHip, geometry: geometry)
                drawLine(path: &path, from: .root, to: .rightHip, geometry: geometry)
                drawLine(path: &path, from: .leftHip, to: .rightHip, geometry: geometry)
                
                // Left Arm
                drawLine(path: &path, from: .leftShoulder, to: .leftElbow, geometry: geometry)
                drawLine(path: &path, from: .leftElbow, to: .leftWrist, geometry: geometry)
                
                // Right Arm
                drawLine(path: &path, from: .rightShoulder, to: .rightElbow, geometry: geometry)
                drawLine(path: &path, from: .rightElbow, to: .rightWrist, geometry: geometry)
                
                // Left Leg
                drawLine(path: &path, from: .leftHip, to: .leftKnee, geometry: geometry)
                drawLine(path: &path, from: .leftKnee, to: .leftAnkle, geometry: geometry)
                
                // Right Leg
                drawLine(path: &path, from: .rightHip, to: .rightKnee, geometry: geometry)
                drawLine(path: &path, from: .rightKnee, to: .rightAnkle, geometry: geometry)
            }
            .stroke(Color.green, lineWidth: 3)
            
            // Draw Joints
            ForEach(getJoints(), id: \.key) { key, point in
                if point.confidence > 0.3 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .position(
                            x: point.location.x * geometry.size.width,
                            y: (1 - point.location.y) * geometry.size.height
                        )
                }
            }
        }
    }
    
    private func drawLine(path: inout Path, from: VNHumanBodyPoseObservation.JointName, to: VNHumanBodyPoseObservation.JointName, geometry: GeometryProxy) {
        guard let p1 = try? bodyPose.recognizedPoint(from),
              let p2 = try? bodyPose.recognizedPoint(to),
              p1.confidence > 0.3, p2.confidence > 0.3 else { return }
        
        path.move(to: CGPoint(
            x: p1.location.x * geometry.size.width,
            y: (1 - p1.location.y) * geometry.size.height
        ))
        
        path.addLine(to: CGPoint(
            x: p2.location.x * geometry.size.width,
            y: (1 - p2.location.y) * geometry.size.height
        ))
    }
    
    private func getJoints() -> [(key: String, point: VNRecognizedPoint)] {
        guard let points = try? bodyPose.recognizedPoints(.all) else { return [] }
        return points.map { ($0.key.rawValue.rawValue, $0.value) }
    }
}
