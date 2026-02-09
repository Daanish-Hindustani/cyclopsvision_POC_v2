"use client";

import React, { useRef, useState, useEffect } from "react";
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { Step } from "@/lib/api";

interface StepsListProps {
    steps: Step[];
    loading?: boolean;
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

export default function StepsList({ steps, loading }: StepsListProps) {
    const [playingClip, setPlayingClip] = useState<number | null>(null);
    const [expandedStep, setExpandedStep] = useState<number | null>(null);
    const videoRefs = useRef<{ [key: number]: HTMLVideoElement | null }>({});

    // Auto-pause video when collapsing a step
    useEffect(() => {
        if (playingClip !== null && expandedStep !== playingClip) {
            const video = videoRefs.current[playingClip];
            if (video) {
                video.pause();
            }
            setPlayingClip(null);
        }
    }, [expandedStep, playingClip]);

    const handleStepClick = (stepId: number) => {
        setExpandedStep(expandedStep === stepId ? null : stepId);
    };

    if (loading) {
        return (
            <div className="space-y-4">
                {[1, 2, 3].map((i) => (
                    <div key={i} className="step-card animate-pulse">
                        <div className="flex gap-4">
                            <div className="w-8 h-8 rounded-full bg-gray-700" />
                            <div className="flex-1 space-y-2">
                                <div className="h-5 bg-gray-700 rounded w-1/3" />
                                <div className="h-4 bg-gray-700/50 rounded w-full" />
                                <div className="h-4 bg-gray-700/50 rounded w-2/3" />
                            </div>
                        </div>
                    </div>
                ))}
            </div>
        );
    }

    if (steps.length === 0) {
        return (
            <div className="text-center py-12 text-gray-400">
                <svg className="w-12 h-12 mx-auto mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                        d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
                <p>No steps extracted yet</p>
                <p className="text-sm mt-1">Upload a demo video to get started</p>
            </div>
        );
    }

    const formatTime = (seconds: number) => {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    return (
        <div className="space-y-4">
            {steps.map((step, index) => {
                const isExpanded = expandedStep === step.step_id;
                const hasClip = !!step.clip_url;

                return (
                    <div
                        key={step.step_id}
                        className={`step-card animate-fade-in transition-all duration-300 ${hasClip ? 'cursor-pointer hover:border-purple-500/50' : ''}`}
                        style={{ animationDelay: `${index * 0.1}s` }}
                        onClick={() => hasClip && handleStepClick(step.step_id)}
                    >
                        <div className="flex gap-4">
                            <div className="step-number">
                                {step.step_id}
                            </div>
                            <div className="flex-1 min-w-0">
                                <div className="flex items-center justify-between">
                                    <h3 className="font-semibold text-lg">{step.title}</h3>
                                    {hasClip && (
                                        <div className="flex items-center gap-2">
                                            <span className="text-xs text-gray-500">
                                                {formatTime(step.start_time)} - {formatTime(step.end_time)}
                                            </span>
                                            <div className={`flex items-center gap-1 text-purple-400 transition-transform duration-200 ${isExpanded ? 'rotate-90' : ''}`}>
                                                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                                                    <path d="M8 5v14l11-7z" />
                                                </svg>
                                                <svg className={`w-4 h-4 transition-transform duration-200 ${isExpanded ? 'rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                                                </svg>
                                            </div>
                                        </div>
                                    )}
                                </div>
                                <div className="text-gray-400 mt-1 prose prose-invert prose-sm max-w-none">
                                    <ReactMarkdown remarkPlugins={[remarkGfm]}>
                                        {step.description}
                                    </ReactMarkdown>
                                </div>

                                {/* Video Clip - Only shows when expanded */}
                                {hasClip && isExpanded && (
                                    <div className="mt-3 rounded-lg overflow-hidden bg-black/40 border border-gray-700 animate-fade-in">
                                        <video
                                            ref={(el) => { videoRefs.current[step.step_id] = el; }}
                                            src={`${API_BASE_URL}${step.clip_url}`}
                                            className="w-full max-h-64 object-contain"
                                            loop
                                            muted
                                            playsInline
                                            autoPlay
                                            onPlay={() => setPlayingClip(step.step_id)}
                                            onPause={() => playingClip === step.step_id && setPlayingClip(null)}
                                        />
                                        <div className="flex items-center justify-between p-2 bg-gray-900/60">
                                            <button
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    const video = videoRefs.current[step.step_id];
                                                    if (video) {
                                                        if (video.paused) {
                                                            video.play();
                                                        } else {
                                                            video.pause();
                                                        }
                                                    }
                                                }}
                                                className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-purple-500/20 text-purple-300 hover:bg-purple-500/30 transition-colors text-sm"
                                            >
                                                {playingClip === step.step_id ? (
                                                    <>
                                                        <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                                                            <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
                                                        </svg>
                                                        Pause
                                                    </>
                                                ) : (
                                                    <>
                                                        <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                                                            <path d="M8 5v14l11-7z" />
                                                        </svg>
                                                        Play Clip
                                                    </>
                                                )}
                                            </button>
                                            <span className="text-xs text-gray-500">
                                                Duration: {formatTime(step.end_time - step.start_time)}
                                            </span>
                                        </div>
                                    </div>
                                )}

                                {/* Expected Objects */}
                                {step.expected_objects.length > 0 && (
                                    <div className="mt-3 flex flex-wrap gap-2">
                                        {step.expected_objects.map((obj) => (
                                            <span
                                                key={obj}
                                                className="px-2 py-1 text-xs rounded-full bg-blue-500/20 text-blue-300 border border-blue-500/30"
                                            >
                                                {obj}
                                            </span>
                                        ))}
                                    </div>
                                )}

                                {/* Motion & Duration */}
                                <div className="mt-3 flex items-center gap-4 text-sm text-gray-500">
                                    {step.expected_motion && (
                                        <span className="flex items-center gap-1">
                                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                                    d="M14 5l7 7m0 0l-7 7m7-7H3" />
                                            </svg>
                                            {step.expected_motion.replace(/_/g, " ")}
                                        </span>
                                    )}
                                    <span className="flex items-center gap-1">
                                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                                        </svg>
                                        ~{step.expected_duration_seconds}s
                                    </span>
                                </div>

                                {/* Mistake Patterns */}
                                {step.mistake_patterns.length > 0 && (
                                    <div className="mt-3 p-3 rounded-lg bg-orange-500/10 border border-orange-500/20">
                                        <p className="text-xs font-medium text-orange-300 mb-2">
                                            Common Mistakes to Watch For:
                                        </p>
                                        <ul className="space-y-1 text-sm text-gray-400">
                                            {step.mistake_patterns.map((mistake) => (
                                                <li key={mistake.type} className="flex items-start gap-2">
                                                    <span className="text-orange-400">•</span>
                                                    {mistake.description}
                                                </li>
                                            ))}
                                        </ul>
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>
                );
            })}
        </div>
    );
}
