"""
CyclopsVision Backend - Lesson Storage Service
Simple JSON-based storage for POC
"""
import json
import os
from pathlib import Path
from typing import List, Optional
from datetime import datetime

from models.lesson import Lesson, TeacherConfig


class LessonStorage:
    """Simple JSON file-based storage for lessons"""
    
    def __init__(self, storage_path: str = "storage/lessons.json"):
        self.storage_path = Path(storage_path)
        self.storage_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize empty storage if file doesn't exist
        if not self.storage_path.exists():
            self._write_lessons([])
    
    def _read_lessons(self) -> List[dict]:
        """Read all lessons from storage"""
        try:
            with open(self.storage_path, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return []
    
    def _write_lessons(self, lessons: List[dict]):
        """Write all lessons to storage"""
        with open(self.storage_path, "w") as f:
            json.dump(lessons, f, indent=2, default=str)
    
    def create(self, lesson: Lesson) -> Lesson:
        """Create a new lesson"""
        lessons = self._read_lessons()
        
        # Convert to dict for storage
        lesson_dict = lesson.model_dump()
        lesson_dict["created_at"] = lesson.created_at.isoformat()
        
        # Convert TeacherConfig to dict if present
        if lesson.ai_teacher_config:
            lesson_dict["ai_teacher_config"] = lesson.ai_teacher_config.model_dump()
        
        lessons.append(lesson_dict)
        self._write_lessons(lessons)
        
        return lesson
    
    def get(self, lesson_id: str) -> Optional[Lesson]:
        """Get a lesson by ID"""
        lessons = self._read_lessons()
        
        for lesson_dict in lessons:
            if lesson_dict.get("id") == lesson_id:
                return self._dict_to_lesson(lesson_dict)
        
        return None
    
    def get_all(self) -> List[Lesson]:
        """Get all lessons"""
        lessons = self._read_lessons()
        return [self._dict_to_lesson(l) for l in lessons]
    
    def update(self, lesson_id: str, updates: dict) -> Optional[Lesson]:
        """Update a lesson"""
        lessons = self._read_lessons()
        
        for i, lesson_dict in enumerate(lessons):
            if lesson_dict.get("id") == lesson_id:
                lesson_dict.update(updates)
                
                # Handle TeacherConfig conversion
                if "ai_teacher_config" in updates and updates["ai_teacher_config"]:
                    if hasattr(updates["ai_teacher_config"], "model_dump"):
                        lesson_dict["ai_teacher_config"] = updates["ai_teacher_config"].model_dump()
                
                lessons[i] = lesson_dict
                self._write_lessons(lessons)
                return self._dict_to_lesson(lesson_dict)
        
        return None
    
    def delete(self, lesson_id: str) -> bool:
        """Delete a lesson"""
        lessons = self._read_lessons()
        original_len = len(lessons)
        lessons = [l for l in lessons if l.get("id") != lesson_id]
        
        if len(lessons) < original_len:
            self._write_lessons(lessons)
            return True
        return False
    
    def _dict_to_lesson(self, data: dict) -> Lesson:
        """Convert storage dict to Lesson model"""
        # Handle TeacherConfig
        if data.get("ai_teacher_config"):
            data["ai_teacher_config"] = TeacherConfig(**data["ai_teacher_config"])
        
        # Handle datetime
        if isinstance(data.get("created_at"), str):
            data["created_at"] = datetime.fromisoformat(data["created_at"])
        
        return Lesson(**data)


# Singleton instance
lesson_storage = LessonStorage()
