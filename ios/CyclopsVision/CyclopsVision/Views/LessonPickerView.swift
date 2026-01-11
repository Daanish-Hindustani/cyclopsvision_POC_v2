import SwiftUI

struct LessonPickerView: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var networkService: NetworkService
    @State private var selectedLesson: Lesson?
    @State private var showingARSession = false
    
    var body: some View {
        NavigationStack {
            Group {
                if lessonStore.isLoading {
                    ProgressView("Loading lessons...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if lessonStore.lessons.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(lessonStore.lessons) { lesson in
                                LessonCardView(lesson: lesson) {
                                    selectedLesson = lesson
                                    showingARSession = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Lessons")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await lessonStore.loadLessons()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingARSession) {
                if let lesson = selectedLesson {
                    ARSessionView(lesson: lesson)
                }
            }
            .onAppear {
                lessonStore.setNetworkService(networkService)
                Task {
                    await lessonStore.loadLessons()
                }
            }
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var networkService: NetworkService
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Lessons Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create lessons using the web app at")
                .foregroundColor(.secondary)
            
            if networkService.isConnected {
                Text("http://localhost:3000")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.purple)
            } else {
                Text("Backend not connected")
                    .foregroundColor(.red)
            }
            
            Button("Refresh") {
                // Trigger refresh via parent
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct LessonCardView: View {
    let lesson: Lesson
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let config = lesson.aiTeacherConfig {
                            Text("\(config.totalSteps) steps")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                
                if let config = lesson.aiTeacherConfig, let firstStep = config.steps.first {
                    Divider()
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.purple)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Text("1")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        
                        Text(firstStep.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Status badge
                HStack {
                    if lesson.aiTeacherConfig != nil {
                        Label("Ready", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Processing", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    Text(formatDate(lesson.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

#Preview {
    LessonPickerView()
        .environmentObject(LessonStore())
        .environmentObject(NetworkService())
}
