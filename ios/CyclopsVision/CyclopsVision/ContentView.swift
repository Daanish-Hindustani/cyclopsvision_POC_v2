import SwiftUI

struct ContentView: View {
    @EnvironmentObject var lessonStore: LessonStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LessonPickerView()
                .tabItem {
                    Label("Lessons", systemImage: "book.fill")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .accentColor(.purple)
    }
}

struct SettingsView: View {
    @EnvironmentObject var networkService: NetworkService
    @AppStorage("backendURL") private var backendURL = "http://192.168.0.156:8000"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Backend Configuration") {
                    TextField("Backend URL", text: $backendURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .onChange(of: backendURL) { _, newValue in
                            networkService.updateBaseURL(newValue)
                        }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        if networkService.isConnected {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Disconnected", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button("Test Connection") {
                        Task {
                            await networkService.checkHealth()
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (POC)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2026.01.11")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LessonStore())
        .environmentObject(NetworkService())
}
