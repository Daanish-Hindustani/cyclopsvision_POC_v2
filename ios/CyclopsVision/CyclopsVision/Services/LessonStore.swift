import Foundation
import Combine

@MainActor
class LessonStore: ObservableObject {
    @Published var lessons: [Lesson] = []
    @Published var selectedLesson: Lesson?
    @Published var isLoading = false
    @Published var error: String?
    
    private var networkService: NetworkService?
    
    func setNetworkService(_ service: NetworkService) {
        self.networkService = service
    }
    
    func loadLessons() async {
        guard let networkService = networkService else {
            error = "Network service not configured"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            lessons = try await networkService.fetchLessons()
        } catch {
            self.error = error.localizedDescription
            print("Failed to load lessons: \(error)")
        }
        
        isLoading = false
    }
    
    func selectLesson(_ lesson: Lesson) {
        selectedLesson = lesson
    }
    
    func refreshLesson() async {
        guard let lesson = selectedLesson,
              let networkService = networkService else { return }
        
        do {
            selectedLesson = try await networkService.fetchLesson(id: lesson.id)
        } catch {
            print("Failed to refresh lesson: \(error)")
        }
    }
}
