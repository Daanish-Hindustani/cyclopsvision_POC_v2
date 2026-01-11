"use client";

import React from "react";
import { Lesson } from "@/lib/api";

interface LessonCardProps {
    lesson: Lesson;
    onSelect: (lesson: Lesson) => void;
    onDelete: (lessonId: string) => void;
}

export default function LessonCard({ lesson, onSelect, onDelete }: LessonCardProps) {
    const stepCount = lesson.ai_teacher_config?.total_steps || 0;
    const createdDate = new Date(lesson.created_at).toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric",
    });

    return (
        <div
            className="glass-card p-5 cursor-pointer hover:border-purple-500/50 transition-all group"
            onClick={() => onSelect(lesson)}
        >
            <div className="flex items-start justify-between">
                <div className="flex-1 min-w-0">
                    <h3 className="font-semibold text-lg truncate group-hover:text-purple-300 transition-colors">
                        {lesson.title}
                    </h3>
                    <div className="flex items-center gap-4 mt-2 text-sm text-gray-400">
                        <span className="flex items-center gap-1">
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                    d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                            </svg>
                            {stepCount} {stepCount === 1 ? "step" : "steps"}
                        </span>
                        <span className="flex items-center gap-1">
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                    d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                            </svg>
                            {createdDate}
                        </span>
                    </div>
                </div>

                <button
                    onClick={(e) => {
                        e.stopPropagation();
                        onDelete(lesson.id);
                    }}
                    className="p-2 rounded-lg hover:bg-red-500/20 text-gray-500 hover:text-red-400 transition-all opacity-0 group-hover:opacity-100"
                    title="Delete lesson"
                >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                </button>
            </div>

            {/* Status indicator */}
            <div className="mt-4 flex items-center gap-2">
                {lesson.ai_teacher_config ? (
                    <span className="px-2 py-1 text-xs rounded-full bg-green-500/20 text-green-400 border border-green-500/30">
                        Ready
                    </span>
                ) : (
                    <span className="px-2 py-1 text-xs rounded-full bg-yellow-500/20 text-yellow-400 border border-yellow-500/30">
                        Processing
                    </span>
                )}
            </div>
        </div>
    );
}
