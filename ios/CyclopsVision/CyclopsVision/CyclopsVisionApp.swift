import SwiftUI

@main
struct CyclopsVisionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
