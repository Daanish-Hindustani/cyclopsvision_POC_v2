import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @Binding var opacity: Double
    
    @State private var isLoading = true
    @State private var errorMessage: String?

    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                 if let player = player {
                     VideoPlayer(player: player)
                         .aspectRatio(contentMode: .fill)
                         .frame(width: geometry.size.width, height: geometry.size.height)
                         .clipped()
                         .opacity(opacity)
                         .onAppear {
                             player.play()
                         }
                 }
                 
                 if isLoading {
                     ProgressView()
                         .tint(.white)
                 }
                 
                 if let error = errorMessage {
                     VStack {
                         Image(systemName: "exclamationmark.triangle.fill")
                             .foregroundColor(.yellow)
                             .font(.largeTitle)
                         Text("Video Error")
                             .font(.caption)
                             .foregroundColor(.white)
                         Text(error)
                             .font(.caption2)
                             .foregroundColor(.white.opacity(0.8))
                             .multilineTextAlignment(.center)
                     }
                     .padding()
                     .background(Color.black.opacity(0.7))
                     .cornerRadius(8)
                 }
             }

        }
        .onAppear {
            setupPlayer()
        }
        .onChange(of: url) { _, newUrl in
            print("🎬 VideoPlayerView: URL changed to \(newUrl.lastPathComponent)")
            player?.pause()
            player = nil
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: url)
        
        // Observe status
        let statusObservation = playerItem.observe(\.status) { item, _ in
            switch item.status {
            case .readyToPlay:
                isLoading = false
            case .failed:
                let error = item.error?.localizedDescription ?? "Unknown error"
                isLoading = false
                errorMessage = error
            case .unknown:
                break
            @unknown default:
                break
            }
        }
        
        // Keep reference to observation if needed, or rely on AVPlayerItem lifetime
        // For simple SwiftUI views trying to keep it lightweight.
        
        self.player = AVPlayer(playerItem: playerItem)
        self.player?.isMuted = true
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            self.player?.seek(to: .zero)
            self.player?.play()
        }
        
        // Auto play immediately
        self.player?.play()
    }

}

#Preview {
    VideoPlayerView(
        url: URL(string: "https://example.com/video.mp4")!,
        opacity: .constant(0.5)
    )
}
