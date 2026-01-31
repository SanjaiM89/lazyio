"""
VidsSave YouTube Downloader Module
Alternative to yt-dlp that uses the VidsSave API for downloads.
Intended as a fallback when yt-dlp faces issues.
"""

import os
import asyncio
import uuid
import re
import subprocess
import urllib.request
import urllib.parse
import json
from typing import Optional, Dict, Any
from dataclasses import dataclass, field
from enum import Enum

# Temp directory for downloads
DOWNLOAD_DIR = os.path.join(os.path.dirname(__file__), "temp_uploads", "youtube_vidssave")
os.makedirs(DOWNLOAD_DIR, exist_ok=True)


class VidsSaveDownloadStatus(Enum):
    PENDING = "pending"
    FETCHING_INFO = "fetching_info"
    DOWNLOADING = "downloading"
    CONVERTING = "converting"
    COMPLETE = "complete"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class VidsSaveDownloadTask:
    task_id: str
    url: str
    status: VidsSaveDownloadStatus = VidsSaveDownloadStatus.PENDING
    progress: int = 0
    title: str = ""
    artist: str = ""
    thumbnail: str = ""
    duration: int = 0
    file_path: Optional[str] = None
    video_path: Optional[str] = None  # Added field
    error: Optional[str] = None


# Global task store
_vidssave_tasks: Dict[str, VidsSaveDownloadTask] = {}


class VidsSaveDownloader:
    """
    YouTube downloader that uses vidssave.com API as backend.
    """
    
    # VidsSave API configuration (reverse-engineered)
    API_ENDPOINT = "https://api.vidssave.com/api/contentsite_api/media/parse"
    AUTH_TOKEN = "20250901majwlqo"  # Appears to be static, may need periodic updates
    API_DOMAIN = "api-ak.vidssave.com"
    
    YOUTUBE_REGEX = re.compile(
        r'(https?://)?(www\.)?(youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/)[\w-]+'
    )
    
    def __init__(self):
        self._cancelled_tasks: set = set()
        self._conversion_sem = asyncio.Semaphore(4)  # Allow 4 concurrent conversions
        print("[VidsSave] VidsSave-based downloader initialized")
    
    def is_youtube_url(self, url: str) -> bool:
        """Check if URL is a valid YouTube URL"""
        return bool(self.YOUTUBE_REGEX.match(url))
    
    async def get_video_info(self, url: str) -> Dict[str, Any]:
        """
        Fetch video information from VidsSave API.
        Returns metadata and list of available formats.
        """
        if not self.is_youtube_url(url):
            raise ValueError("Invalid YouTube URL")
        
        def _fetch_info():
            # Prepare request data
            data = urllib.parse.urlencode({
                "auth": self.AUTH_TOKEN,
                "domain": self.API_DOMAIN,
                "origin": "cache",
                "link": url
            }).encode('utf-8')
            
            # Create request with headers
            req = urllib.request.Request(
                self.API_ENDPOINT,
                data=data,
                headers={
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Origin": "https://vidssave.com",
                    "Referer": "https://vidssave.com/",
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                }
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode('utf-8'))
            
            if result.get("status") != 1:
                raise Exception(f"VidsSave API error: {result}")
            
            return result.get("data", {})
        
        loop = asyncio.get_event_loop()
        info = await loop.run_in_executor(None, _fetch_info)
        
        # Parse artist from title (common format: "Artist - Title")
        title = info.get("title", "Unknown")
        artist = "" # Default to empty if not found
        if " - " in title:
            parts = title.split(" - ", 1)
            artist = parts[0].strip()
            title = parts[1].strip()
        
        return {
            "title": title,
            "artist": artist,
            "thumbnail": info.get("thumbnail", ""),
            "duration": info.get("duration", 0),
            "resources": info.get("resources", [])
        }
    
    async def get_formats(self, url: str) -> list:
        """Get available formats for a video"""
        info = await self.get_video_info(url)
        resources = info.get("resources", [])
        
        # Filter and format for UI consistency
        formats = []
        for r in resources:
            quality_str = r.get("quality", "").upper()
            abr = None
            note = quality_str
            
            # Extract bitrate for audio
            if "KBPS" in quality_str:
                try:
                    abr = int(quality_str.replace("KBPS", ""))
                except ValueError:
                    pass
            
            # Use quality as note for video (e.g. 720P)
            if r.get("type") == "video":
                note = f"{quality_str} Video"

            formats.append({
                "format_id": f"{r.get('format', 'unknown')}_{r.get('quality', 'unknown')}",
                "ext": r.get("format", "").lower(),
                "quality": r.get("quality", ""),
                "type": r.get("type", ""),
                "filesize": r.get("size", 0),
                "download_url": r.get("download_url", ""),
                "abr": abr,
                "note": note
            })
        
        # Sort: video by quality (descending), then audio
        def sort_key(f):
            quality = f.get("quality", "").replace("P", "").replace("KBPS", "")
            try:
                return int(quality)
            except ValueError:
                return 0
        
        formats.sort(key=sort_key, reverse=True)
        return formats
    
    def _select_best_video(self, resources: list) -> Optional[Dict]:
        """Select highest quality video from resources"""
        videos = [r for r in resources if r.get("type") == "video"]
        if not videos:
            return None
        
        # Sort by quality (e.g., 2160P > 1080P > 720P)
        def quality_key(r):
            q = r.get("quality", "").replace("P", "")
            try:
                return int(q)
            except ValueError:
                return 0
        
        videos.sort(key=quality_key, reverse=True)
        return videos[0]
    
    async def download_and_convert(
        self,
        url: str,
        task_id: Optional[str] = None,
        broadcast_callback=None
    ) -> VidsSaveDownloadTask:
        """
        Download highest quality video and convert to audio.
        """
        # Create or retrieve task
        if task_id and task_id in _vidssave_tasks:
            task = _vidssave_tasks[task_id]
        else:
            task_id = task_id or str(uuid.uuid4())
            task = VidsSaveDownloadTask(task_id=task_id, url=url)
            _vidssave_tasks[task_id] = task
        
        if not self.is_youtube_url(url):
            task.status = VidsSaveDownloadStatus.FAILED
            task.error = "Invalid YouTube URL"
            return task
        
        try:
            # Stage 1: Fetch video info
            task.status = VidsSaveDownloadStatus.FETCHING_INFO
            if broadcast_callback:
                await broadcast_callback("youtube_progress", {
                    "task_id": task_id,
                    "status": "fetching_info",
                    "progress": 5,
                    "message": "Fetching video information..."
                })
            
            info = await self.get_video_info(url)
            task.title = info["title"]
            task.artist = info["artist"]
            task.thumbnail = info["thumbnail"]
            task.duration = info["duration"]
            task.progress = 10
            
            # Find best video format
            best_video = self._select_best_video(info["resources"])
            if not best_video:
                raise Exception("No video formats available")
            
            print(f"[VidsSave] Selected: {best_video['quality']} ({best_video['size'] / 1024 / 1024:.1f} MB)")
            
            # Stage 2: Download video
            task.status = VidsSaveDownloadStatus.DOWNLOADING
            if broadcast_callback:
                await broadcast_callback("youtube_progress", {
                    "task_id": task_id,
                    "status": "downloading",
                    "progress": 15,
                    "message": f"Downloading {best_video['quality']} video..."
                })
            
            # Create filenames
            safe_title = re.sub(r'[^\w\s-]', '', task.title)[:50]
            video_filename = f"{task_id}_{safe_title}.mp4"
            audio_filename = f"{task_id}_{safe_title}.mp3"
            video_path = os.path.join(DOWNLOAD_DIR, video_filename)
            audio_path = os.path.join(DOWNLOAD_DIR, audio_filename)
            
            # Download video file
            download_url = best_video["download_url"]
            total_size = best_video.get("size", 0)
            
            def _download_video():
                req = urllib.request.Request(
                    download_url,
                    headers={
                        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                        "Referer": "https://vidssave.com/"
                    }
                )
                
                with urllib.request.urlopen(req, timeout=300) as response:
                    with open(video_path, 'wb') as f:
                        downloaded = 0
                        chunk_size = 1024 * 1024  # 1 MB chunks
                        while True:
                            chunk = response.read(chunk_size)
                            if not chunk:
                                break
                            f.write(chunk)
                            downloaded += len(chunk)
                            
                            # Calculate progress (15-80% for download)
                            if total_size > 0:
                                task.progress = 15 + int((downloaded / total_size) * 65)
                
                return video_path
            
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(None, _download_video)
            
            # Store video path in task
            task.video_path = video_path
            
            # Stage 3: Convert to audio using FFmpeg
            async with self._conversion_sem:
                task.status = VidsSaveDownloadStatus.CONVERTING
                task.progress = 80
                if broadcast_callback:
                    await broadcast_callback("youtube_progress", {
                        "task_id": task_id,
                        "status": "converting",
                        "progress": 80,
                        "message": "Converting to audio..."
                    })
                
                def _convert_to_audio():
                    cmd = [
                        "ffmpeg", "-i", video_path,
                        "-vn",  # No video
                        "-acodec", "libmp3lame",
                        "-ab", "320k",  # High quality
                        "-ar", "44100",
                        "-y",  # Overwrite
                        audio_path
                    ]
                    subprocess.run(cmd, check=True, capture_output=True)
                    return audio_path
                
                try:
                    await loop.run_in_executor(None, _convert_to_audio)
                except subprocess.CalledProcessError as e:
                    error_msg = e.stderr.decode() if e.stderr else str(e)
                    print(f"[VidsSave] FFmpeg Error: {error_msg}")
                    # Re-raise with detail
                    raise Exception(f"Conversion failed (Exit {e.returncode}): {error_msg[-200:]}")
            
            # Done!
            task.status = VidsSaveDownloadStatus.COMPLETE
            task.progress = 100
            task.file_path = audio_path
            
            if broadcast_callback:
                await broadcast_callback("youtube_progress", {
                    "task_id": task_id,
                    "status": "complete",
                    "progress": 100,
                    "message": "Download complete!",
                    "file_path": audio_path
                })
            
            print(f"[VidsSave] Complete: {audio_path}")
            return task
            
        except Exception as e:
            task.status = VidsSaveDownloadStatus.FAILED
            task.error = str(e)
            print(f"[VidsSave] Error: {e}")
            
            if broadcast_callback:
                await broadcast_callback("youtube_progress", {
                    "task_id": task_id,
                    "status": "failed",
                    "progress": 0,
                    "error": str(e)
                })
            
            return task
    
    def cancel_task(self, task_id: str):
        """Cancel a running download task"""
        self._cancelled_tasks.add(task_id)
        if task_id in _vidssave_tasks:
            _vidssave_tasks[task_id].status = VidsSaveDownloadStatus.CANCELLED



def get_vidssave_task(task_id: str) -> Optional[VidsSaveDownloadTask]:
    """Get a VidsSave download task by ID"""
    return _vidssave_tasks.get(task_id)


def get_all_tasks() -> list[VidsSaveDownloadTask]:
    """Get all VidsSave download tasks"""
    return list(_vidssave_tasks.values())


# Global instance
vidssave_downloader = VidsSaveDownloader()
