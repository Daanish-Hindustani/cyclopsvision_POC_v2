"use client";

import React, { useState, useEffect, useCallback } from "react";
import VideoUploader from "./components/VideoUploader";
import StepsList from "./components/StepsList";
import TeacherConfigViewer from "./components/TeacherConfigViewer";
import LessonCard from "./components/LessonCard";
import { api, Lesson } from "@/lib/api";

type ViewMode = "create" | "list" | "detail";

export default function Home() {
  const [viewMode, setViewMode] = useState<ViewMode>("create");
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [selectedLesson, setSelectedLesson] = useState<Lesson | null>(null);
  const [title, setTitle] = useState("");
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [apiStatus, setApiStatus] = useState<"checking" | "online" | "offline">("checking");
  const [regenerating, setRegenerating] = useState(false);

  // Check API health on mount
  useEffect(() => {
    const checkApi = async () => {
      try {
        await api.checkHealth();
        setApiStatus("online");
        loadLessons();
      } catch {
        setApiStatus("offline");
      }
    };
    checkApi();
  }, []);

  const loadLessons = async () => {
    try {
      const data = await api.getLessons();
      setLessons(data);
    } catch (err) {
      console.error("Failed to load lessons:", err);
    }
  };

  const handleFileSelect = useCallback(async (file: File) => {
    if (!title.trim()) {
      // Auto-generate title from filename
      setTitle(file.name.replace(/\.[^/.]+$/, ""));
    }
  }, [title]);

  const handleCreateLesson = async (file: File) => {
    setUploading(true);
    setError(null);
    setProgress(10);

    try {
      // Simulate progress updates
      const progressInterval = setInterval(() => {
        setProgress((prev) => Math.min(prev + 5, 90));
      }, 1000);

      const lesson = await api.createLesson(file, title || "Untitled Lesson");

      clearInterval(progressInterval);
      setProgress(100);

      setSelectedLesson(lesson);
      setViewMode("detail");
      setTitle("");
      loadLessons();

    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create lesson");
    } finally {
      setUploading(false);
      setProgress(0);
    }
  };

  const handleDeleteLesson = async (lessonId: string) => {
    if (!confirm("Are you sure you want to delete this lesson?")) {
      return;
    }

    try {
      await api.deleteLesson(lessonId);
      setLessons((prev) => prev.filter((l) => l.id !== lessonId));
      if (selectedLesson?.id === lessonId) {
        setSelectedLesson(null);
        setViewMode("list");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to delete lesson");
    }
  };

  const handleRegenerateClips = async (lessonId: string) => {
    setRegenerating(true);
    setError(null);

    try {
      const updatedLesson = await api.regenerateClips(lessonId);
      setSelectedLesson(updatedLesson);
      // Update the lesson in the list too
      setLessons((prev) =>
        prev.map((l) => (l.id === lessonId ? updatedLesson : l))
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to regenerate clips");
    } finally {
      setRegenerating(false);
    }
  };

  return (
    <main className="min-h-screen">
      {/* Header */}
      <header className="border-b border-gray-800 bg-black/40 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-6xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-indigo-600 flex items-center justify-center">
                <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
              </div>
              <div>
                <h1 className="text-xl font-bold">
                  <span className="gradient-text">CyclopsVision</span>
                </h1>
                <p className="text-xs text-gray-400">AI-Guided AR Training</p>
              </div>
            </div>

            <div className="flex items-center gap-4">
              {/* API Status */}
              <div className="flex items-center gap-2 text-sm">
                <div className={`w-2 h-2 rounded-full ${apiStatus === "online" ? "bg-green-500" :
                  apiStatus === "offline" ? "bg-red-500" : "bg-yellow-500"
                  }`} />
                <span className="text-gray-400">
                  {apiStatus === "online" ? "Backend Connected" :
                    apiStatus === "offline" ? "Backend Offline" : "Checking..."}
                </span>
              </div>

              {/* Navigation */}
              <div className="flex gap-2">
                <button
                  onClick={() => setViewMode("create")}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${viewMode === "create"
                    ? "bg-purple-500/20 text-purple-300 border border-purple-500/30"
                    : "text-gray-400 hover:text-white hover:bg-gray-800"
                    }`}
                >
                  Create
                </button>
                <button
                  onClick={() => { setViewMode("list"); loadLessons(); }}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${viewMode === "list" || viewMode === "detail"
                    ? "bg-purple-500/20 text-purple-300 border border-purple-500/30"
                    : "text-gray-400 hover:text-white hover:bg-gray-800"
                    }`}
                >
                  Lessons ({lessons.length})
                </button>
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <div className="max-w-6xl mx-auto px-6 py-8">
        {/* Error Alert */}
        {error && (
          <div className="mb-6 p-4 rounded-lg bg-red-500/20 border border-red-500/30 text-red-300 flex items-center gap-3">
            <svg className="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span>{error}</span>
            <button onClick={() => setError(null)} className="ml-auto text-red-400 hover:text-red-300">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        )}

        {/* API Offline Warning */}
        {apiStatus === "offline" && (
          <div className="mb-6 p-4 rounded-lg bg-yellow-500/20 border border-yellow-500/30 text-yellow-300">
            <div className="flex items-center gap-3">
              <svg className="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              <div>
                <p className="font-medium">Backend server is not running</p>
                <p className="text-sm opacity-75 mt-1">
                  Start the backend with: <code className="bg-black/30 px-2 py-0.5 rounded">cd backend && python main.py</code>
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Create View */}
        {viewMode === "create" && (
          <div className="space-y-6">
            <div className="text-center mb-8">
              <h2 className="text-3xl font-bold">Create a New Lesson</h2>
              <p className="text-gray-400 mt-2">
                Upload a demo video and our AI will extract the procedural steps automatically
              </p>
            </div>

            <div className="glass-card p-6">
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Lesson Title
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="e.g., How to Wire a Terminal"
                  className="input"
                  disabled={uploading}
                />
              </div>

              <VideoUploader
                onFileSelect={(file) => {
                  handleFileSelect(file);
                  // Start upload when file is selected
                  if (apiStatus === "online") {
                    handleCreateLesson(file);
                  }
                }}
                uploading={uploading}
                progress={progress}
              />
            </div>

            {/* How it works */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-12">
              {[
                {
                  icon: (
                    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
                    </svg>
                  ),
                  title: "Upload Video",
                  description: "Record a demo of the procedure and upload it here",
                },
                {
                  icon: (
                    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                  ),
                  title: "AI Extraction",
                  description: "Gemini AI analyzes frames and extracts procedural steps",
                },
                {
                  icon: (
                    <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
                    </svg>
                  ),
                  title: "Train on iOS",
                  description: "Use the lesson in the CyclopsVision iOS app with AR guidance",
                },
              ].map((step, i) => (
                <div key={i} className="glass-card p-6 text-center">
                  <div className="w-12 h-12 rounded-xl bg-purple-500/20 flex items-center justify-center mx-auto mb-4 text-purple-400">
                    {step.icon}
                  </div>
                  <h3 className="font-semibold mb-2">{step.title}</h3>
                  <p className="text-sm text-gray-400">{step.description}</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* List View */}
        {viewMode === "list" && (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h2 className="text-2xl font-bold">Your Lessons</h2>
              <button
                onClick={() => setViewMode("create")}
                className="btn-primary"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                New Lesson
              </button>
            </div>

            {lessons.length === 0 ? (
              <div className="text-center py-16">
                <div className="w-16 h-16 rounded-full bg-gray-800 flex items-center justify-center mx-auto mb-4">
                  <svg className="w-8 h-8 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                      d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                  </svg>
                </div>
                <h3 className="text-lg font-medium mb-2">No lessons yet</h3>
                <p className="text-gray-400 mb-6">Create your first lesson by uploading a demo video</p>
                <button onClick={() => setViewMode("create")} className="btn-primary">
                  Create First Lesson
                </button>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {lessons.map((lesson) => (
                  <LessonCard
                    key={lesson.id}
                    lesson={lesson}
                    onSelect={(l) => { setSelectedLesson(l); setViewMode("detail"); }}
                    onDelete={handleDeleteLesson}
                  />
                ))}
              </div>
            )}
          </div>
        )}

        {/* Detail View */}
        {viewMode === "detail" && selectedLesson && (
          <div className="space-y-6">
            <button
              onClick={() => setViewMode("list")}
              className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
              </svg>
              Back to Lessons
            </button>

            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-2xl font-bold">{selectedLesson.title}</h2>
                <p className="text-gray-400 mt-1">
                  Created {new Date(selectedLesson.created_at).toLocaleDateString()}
                </p>
              </div>
              <div className="flex items-center gap-2">
                {selectedLesson.ai_teacher_config && (
                  <span className="px-3 py-1 text-sm rounded-full bg-green-500/20 text-green-400 border border-green-500/30">
                    {selectedLesson.ai_teacher_config.total_steps} steps extracted
                  </span>
                )}
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Steps Section */}
              <div className="lg:col-span-2 space-y-6">
                <div className="glass-card p-6">
                  <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
                    <svg className="w-5 h-5 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                    </svg>
                    Extracted Steps
                  </h3>
                  <StepsList steps={selectedLesson.ai_teacher_config?.steps || []} />
                </div>
              </div>

              {/* Sidebar */}
              <div className="space-y-6">
                {/* Quick Actions */}
                <div className="glass-card p-6">
                  <h3 className="text-lg font-semibold mb-4">Quick Actions</h3>
                  <div className="space-y-3">
                    <button className="btn-primary w-full">
                      <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                          d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
                      </svg>
                      Open in iOS App
                    </button>
                    <button
                      onClick={() => handleRegenerateClips(selectedLesson.id)}
                      disabled={regenerating}
                      className="btn-secondary w-full flex items-center justify-center gap-2"
                    >
                      {regenerating ? (
                        <>
                          <svg className="w-5 h-5 animate-spin" fill="none" viewBox="0 0 24 24">
                            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                          </svg>
                          Generating Clips...
                        </>
                      ) : (
                        <>
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                              d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                          </svg>
                          Regenerate Video Clips
                        </>
                      )}
                    </button>
                    <button
                      onClick={() => handleDeleteLesson(selectedLesson.id)}
                      className="btn-secondary w-full text-red-400 border-red-500/30 hover:bg-red-500/20 hover:text-red-300"
                    >
                      Delete Lesson
                    </button>
                  </div>
                </div>

                {/* Teacher Config */}
                <TeacherConfigViewer config={selectedLesson.ai_teacher_config} />
              </div>
            </div>
          </div>
        )}
      </div>
    </main>
  );
}
