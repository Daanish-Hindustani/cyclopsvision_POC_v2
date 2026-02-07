/**
 * CyclopsVision Web - API Client
 */

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000';

export interface MistakePattern {
    type: string;
    description: string;
}

export interface Step {
    step_id: number;
    title: string;
    description: string;
    expected_objects: string[];
    expected_motion: string;
    expected_duration_seconds: number;
    mistake_patterns: MistakePattern[];
    correction_mode: string;
    // Video snippet fields
    start_time: number;
    end_time: number;
    clip_url: string | null;
}

export interface TeacherConfig {
    lesson_id: string;
    total_steps: number;
    steps: Step[];
}

export interface Lesson {
    id: string;
    title: string;
    demo_video_url: string;
    ai_teacher_config: TeacherConfig | null;
    created_at: string;
}

export interface ApiError {
    detail: string;
}

class ApiClient {
    private baseUrl: string;

    constructor(baseUrl: string = API_BASE_URL) {
        this.baseUrl = baseUrl;
    }

    /**
     * Create a new lesson from a video file
     */
    async createLesson(video: File, title: string, onProgress?: (progress: number) => void): Promise<Lesson> {
        const formData = new FormData();
        formData.append('video', video);
        formData.append('title', title);

        const response = await fetch(`${this.baseUrl}/lessons`, {
            method: 'POST',
            body: formData,
        });

        if (!response.ok) {
            const error: ApiError = await response.json();
            throw new Error(error.detail || 'Failed to create lesson');
        }

        return response.json();
    }

    /**
     * Get all lessons
     */
    async getLessons(): Promise<Lesson[]> {
        const response = await fetch(`${this.baseUrl}/lessons`);

        if (!response.ok) {
            throw new Error('Failed to fetch lessons');
        }

        return response.json();
    }

    /**
     * Get a specific lesson by ID
     */
    async getLesson(id: string): Promise<Lesson> {
        const response = await fetch(`${this.baseUrl}/lessons/${id}`);

        if (!response.ok) {
            throw new Error('Lesson not found');
        }

        return response.json();
    }

    /**
     * Delete a lesson
     */
    async deleteLesson(id: string): Promise<void> {
        const response = await fetch(`${this.baseUrl}/lessons/${id}`, {
            method: 'DELETE',
        });

        if (!response.ok) {
            throw new Error('Failed to delete lesson');
        }
    }

    /**
     * Regenerate video clips for an existing lesson
     */
    async regenerateClips(id: string): Promise<Lesson> {
        const response = await fetch(`${this.baseUrl}/lessons/${id}/regenerate-clips`, {
            method: 'POST',
        });

        if (!response.ok) {
            const error: ApiError = await response.json();
            throw new Error(error.detail || 'Failed to regenerate clips');
        }

        return response.json();
    }

    /**
     * Check API health
     */
    async checkHealth(): Promise<{ status: string }> {
        const response = await fetch(`${this.baseUrl}/health`);
        return response.json();
    }
}

export const api = new ApiClient();
export default api;
