import SwiftUI

@main
struct CyclopsVisionApp: App {
    @StateObject private var lessonStore = LessonStore()
    @StateObject private var networkService = NetworkService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(lessonStore)
                .environmentObject(networkService)
                .preferredColorScheme(.dark)
        }
    }
}
