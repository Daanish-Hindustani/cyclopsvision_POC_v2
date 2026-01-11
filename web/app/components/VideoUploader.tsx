"use client";

import React, { useCallback, useState } from "react";

interface VideoUploaderProps {
    onFileSelect: (file: File) => void;
    uploading: boolean;
    progress: number;
}

export default function VideoUploader({ onFileSelect, uploading, progress }: VideoUploaderProps) {
    const [isDragOver, setIsDragOver] = useState(false);
    const [selectedFile, setSelectedFile] = useState<File | null>(null);

    const handleDragOver = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        setIsDragOver(true);
    }, []);

    const handleDragLeave = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        setIsDragOver(false);
    }, []);

    const handleDrop = useCallback((e: React.DragEvent) => {
        e.preventDefault();
        setIsDragOver(false);

        const files = e.dataTransfer.files;
        if (files.length > 0 && files[0].type.startsWith("video/")) {
            setSelectedFile(files[0]);
            onFileSelect(files[0]);
        }
    }, [onFileSelect]);

    const handleFileInput = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const files = e.target.files;
        if (files && files.length > 0) {
            setSelectedFile(files[0]);
            onFileSelect(files[0]);
        }
    }, [onFileSelect]);

    const formatFileSize = (bytes: number) => {
        if (bytes < 1024) return `${bytes} B`;
        if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
        return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    };

    return (
        <div
            className={`upload-zone ${isDragOver ? "drag-over" : ""} ${uploading ? "uploading" : ""}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={() => !uploading && document.getElementById("video-input")?.click()}
        >
            <input
                id="video-input"
                type="file"
                accept="video/*"
                className="hidden"
                onChange={handleFileInput}
                disabled={uploading}
            />

            {uploading ? (
                <div className="flex flex-col items-center gap-4">
                    <div className="spinner" />
                    <p className="text-lg font-medium">
                        Processing video with AI...
                    </p>
                    <p className="text-sm text-gray-400">
                        Extracting frames and analyzing content
                    </p>
                    {progress > 0 && (
                        <div className="w-64 mt-2">
                            <div className="progress-bar">
                                <div className="progress-fill" style={{ width: `${progress}%` }} />
                            </div>
                            <p className="text-xs text-gray-500 mt-1 text-center">{Math.round(progress)}%</p>
                        </div>
                    )}
                </div>
            ) : selectedFile ? (
                <div className="flex flex-col items-center gap-4">
                    <div className="w-16 h-16 rounded-full bg-green-500/20 flex items-center justify-center">
                        <svg className="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                    </div>
                    <p className="text-lg font-medium">{selectedFile.name}</p>
                    <p className="text-sm text-gray-400">{formatFileSize(selectedFile.size)}</p>
                    <p className="text-xs text-gray-500">Click to select a different file</p>
                </div>
            ) : (
                <div className="flex flex-col items-center gap-4">
                    <div className="w-16 h-16 rounded-full bg-purple-500/20 flex items-center justify-center">
                        <svg className="w-8 h-8 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                        </svg>
                    </div>
                    <div>
                        <p className="text-lg font-medium">
                            Drop your demo video here
                        </p>
                        <p className="text-sm text-gray-400 mt-1">
                            or click to browse
                        </p>
                    </div>
                    <p className="text-xs text-gray-500 mt-2">
                        Supports MP4, MOV, AVI, WebM
                    </p>
                </div>
            )}
        </div>
    );
}
