"use client";

import React, { useState } from "react";
import { TeacherConfig } from "@/lib/api";

interface TeacherConfigViewerProps {
    config: TeacherConfig | null;
}

export default function TeacherConfigViewer({ config }: TeacherConfigViewerProps) {
    const [isExpanded, setIsExpanded] = useState(false);

    if (!config) {
        return null;
    }

    const formatJson = (obj: unknown): string => {
        return JSON.stringify(obj, null, 2);
    };

    return (
        <div className="glass-card p-6">
            <button
                onClick={() => setIsExpanded(!isExpanded)}
                className="w-full flex items-center justify-between text-left"
            >
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-cyan-500/20 flex items-center justify-center">
                        <svg className="w-5 h-5 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
                        </svg>
                    </div>
                    <div>
                        <h3 className="font-semibold">AI Teacher Configuration</h3>
                        <p className="text-sm text-gray-400">Raw JSON config for iOS app</p>
                    </div>
                </div>
                <svg
                    className={`w-5 h-5 text-gray-400 transition-transform ${isExpanded ? "rotate-180" : ""}`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
            </button>

            {isExpanded && (
                <div className="mt-4 animate-fade-in">
                    <div className="json-viewer max-h-96 overflow-y-auto">
                        <pre className="text-sm">
                            <code dangerouslySetInnerHTML={{
                                __html: formatJson(config)
                                    .replace(/"([^"]+)":/g, '<span class="json-key">"$1"</span>:')
                                    .replace(/: "([^"]+)"/g, ': <span class="json-string">"$1"</span>')
                                    .replace(/: (\d+)/g, ': <span class="json-number">$1</span>')
                                    .replace(/: (true|false)/g, ': <span class="json-boolean">$1</span>')
                            }} />
                        </pre>
                    </div>
                    <div className="mt-4 flex gap-2">
                        <button
                            onClick={() => {
                                navigator.clipboard.writeText(formatJson(config));
                            }}
                            className="btn-secondary text-sm py-2 px-4"
                        >
                            Copy JSON
                        </button>
                        <button
                            onClick={() => {
                                const blob = new Blob([formatJson(config)], { type: "application/json" });
                                const url = URL.createObjectURL(blob);
                                const a = document.createElement("a");
                                a.href = url;
                                a.download = `teacher_config_${config.lesson_id}.json`;
                                a.click();
                                URL.revokeObjectURL(url);
                            }}
                            className="btn-secondary text-sm py-2 px-4"
                        >
                            Download
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
