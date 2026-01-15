"""
YouTube Audio Downloader Module
Inspired by WZML-X implementation - uses yt-dlp for downloading best audio
"""

import os
import asyncio
import uuid
from typing import Optional, Dict, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
from yt_dlp import YoutubeDL
import re

# Temp directory for downloads
DOWNLOAD_DIR = os.path.join(os.path.dirname(__file__), "temp_uploads", "youtube")
os.makedirs(DOWNLOAD_DIR, exist_ok=True)


class DownloadStatus(Enum):
    PENDING = "pending"
    FETCHING_INFO = "fetching_info"
    DOWNLOADING = "downloading"
    CONVERTING = "converting"
    UPLOADING = "uploading"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class DownloadTask:
    """Represents a YouTube download task with progress tracking"""
    task_id: str
    url: str
    status: DownloadStatus = DownloadStatus.PENDING
    progress: float = 0.0
    title: str = ""
    artist: str = ""
    thumbnail: str = ""
    duration: int = 0
    file_path: str = ""
    file_size: int = 0
    error: str = ""
    quality: str = "320"
    telegram_msg_id: Optional[int] = None
    song_id: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "task_id": self.task_id,
            "url": self.url,
            "status": self.status.value,
            "progress": round(self.progress, 1),
            "title": self.title,
            "artist": self.artist,
            "thumbnail": self.thumbnail,
            "duration": self.duration,
            "file_size": self.file_size,
            "error": self.error,
            "quality": self.quality,
            "song_id": self.song_id,
        }


# Global task storage
_download_tasks: Dict[str, DownloadTask] = {}


class YouTubeDownloader:
    """YouTube audio downloader using yt-dlp"""
    
    # Quality presets (bitrate in kbps)
    QUALITY_PRESETS = {
        "320": {"preferredcodec": "mp3", "preferredquality": "320"},
        "256": {"preferredcodec": "mp3", "preferredquality": "256"},
        "192": {"preferredcodec": "mp3", "preferredquality": "192"},
        "128": {"preferredcodec": "mp3", "preferredquality": "128"},
        "m4a": {"preferredcodec": "m4a", "preferredquality": "256"},
    }
    
    # YouTube URL patterns
    YT_PATTERNS = [
        r'(https?://)?(www\.)?youtube\.com/watch\?v=[\w-]+',
        r'(https?://)?(www\.)?youtu\.be/[\w-]+',
        r'(https?://)?(www\.)?youtube\.com/shorts/[\w-]+',
        r'(https?://)?music\.youtube\.com/watch\?v=[\w-]+',
        r'(https?://)?(www\.)?youtube\.com/playlist\?list=[\w-]+',
    ]
    
    def __init__(self):
        self._cancelled_tasks: set = set()
    
    @classmethod
    def is_youtube_url(cls, url: str) -> bool:
        """Validate if URL is a YouTube link or search query"""
        if url.startswith("ytsearch:") or url.startswith("ytsearch1:"):
            return True
        for pattern in cls.YT_PATTERNS:
            if re.match(pattern, url):
                return True
        return False
    
    @classmethod
    def extract_video_id(cls, url: str) -> Optional[str]:
        """Extract video ID from YouTube URL"""
        patterns = [
            r'(?:v=|/)([0-9A-Za-z_-]{11}).*',
            r'(?:youtu\.be/)([0-9A-Za-z_-]{11})',
            r'(?:shorts/)([0-9A-Za-z_-]{11})',
        ]
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return None

    async def extract_playlist_info(self, url: str) -> list[Dict[str, Any]]:
        """Extract all videos from a playlist URL without downloading"""
        # Run in executor to avoid blocking
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self._extract_playlist_info_sync, url)

    def _extract_playlist_info_sync(self, url: str) -> list[Dict[str, Any]]:
        """Sync worker for playlist extraction"""
        ydl_opts = {
            'extract_flat': True,  # Don't download, just get metadata
            'quiet': True,
            'ignoreerrors': True,
            'no_warnings': True,
        }
        
        with YoutubeDL(ydl_opts) as ydl:
            try:
                info = ydl.extract_info(url, download=False)
                if 'entries' in info:
                    # It's a playlist
                    return [{
                        'url': f"https://www.youtube.com/watch?v={entry['id']}",
                        'title': entry.get('title', 'Unknown'),
                        'id': entry.get('id')
                    } for entry in info['entries'] if entry]
                else:
                    # It's a single video, return as list of one
                    return [{
                        'url': info.get('webpage_url', url),
                        'title': info.get('title', 'Unknown'),
                        'id': info.get('id')
                    }]
            except Exception as e:
                print(f"Error extracting playlist: {e}")
                return []

    
    async def get_video_info(self, url: str) -> Dict[str, Any]:
        """Fetch video metadata without downloading"""
        opts = {
            "quiet": True,
            "no_warnings": True,
            "extract_flat": False,
        }
        
        def _extract():
            with YoutubeDL(opts) as ydl:
                info = ydl.extract_info(url, download=False)
                return info
        
        loop = asyncio.get_event_loop()
        info = await loop.run_in_executor(None, _extract)
        
        if not info:
            raise ValueError("Could not fetch video info")
        
        # Parse artist from various fields
        artist = info.get("artist") or info.get("uploader") or info.get("channel") or "Unknown Artist"
        title = info.get("title", "Unknown Title")
        
        # Clean up title - remove artist name if it's in the title
        if " - " in title:
            parts = title.split(" - ", 1)
            if len(parts) == 2:
                # Common format: "Artist - Song Title"
                potential_artist = parts[0].strip()
                potential_title = parts[1].strip()
                if potential_artist.lower() in artist.lower() or artist.lower() in potential_artist.lower():
                    title = potential_title
                    artist = potential_artist
        
        return {
            "title": title,
            "artist": artist,
            "thumbnail": info.get("thumbnail", ""),
            "duration": info.get("duration", 0),
            "view_count": info.get("view_count", 0),
            "channel": info.get("channel", ""),
            "video_id": info.get("id", ""),
        }
    
    def _create_progress_hook(self, task: DownloadTask):
        """Create a progress hook for yt-dlp"""
        def hook(d):
            if task.task_id in self._cancelled_tasks:
                raise ValueError("Download cancelled by user")
            
            if d["status"] == "downloading":
                task.status = DownloadStatus.DOWNLOADING
                
                # Calculate progress
                total = d.get("total_bytes") or d.get("total_bytes_estimate", 0)
                downloaded = d.get("downloaded_bytes", 0)
                
                if total > 0:
                    task.progress = (downloaded / total) * 80  # Reserve 20% for conversion/upload
                    task.file_size = total
                    
            elif d["status"] == "finished":
                task.status = DownloadStatus.CONVERTING
                task.progress = 80
                task.file_path = d.get("filename", "")
                
        return hook
    
    async def download_audio(
        self, 
        url: str, 
        quality: str = "320",
        task_id: Optional[str] = None
    ) -> DownloadTask:
        """Download audio from YouTube URL"""
        
        # Create or get task
        if task_id and task_id in _download_tasks:
            task = _download_tasks[task_id]
        else:
            task_id = task_id or str(uuid.uuid4())
            task = DownloadTask(
                task_id=task_id,
                url=url,
                quality=quality
            )
            _download_tasks[task_id] = task
        
        # Validate URL
        if not self.is_youtube_url(url):
            task.status = DownloadStatus.FAILED
            task.error = "Invalid YouTube URL"
            return task
        
        # Get quality settings
        quality_opts = self.QUALITY_PRESETS.get(quality, self.QUALITY_PRESETS["320"])
        
        try:
            # Fetch video info first
            task.status = DownloadStatus.FETCHING_INFO
            info = await self.get_video_info(url)
            task.title = info["title"]
            task.artist = info["artist"]
            task.thumbnail = info["thumbnail"]
            task.duration = info["duration"]
            task.progress = 5
            
            # Setup download options
            output_template = os.path.join(
                DOWNLOAD_DIR, 
                f"{task_id}_%(title)s.%(ext)s"
            )
            
            opts = {
                "format": "bestaudio/best",
                "outtmpl": output_template,
                "quiet": True,
                "no_warnings": True,
                "progress_hooks": [self._create_progress_hook(task)],
                "postprocessors": [
                    {
                        "key": "FFmpegExtractAudio",
                        "preferredcodec": quality_opts["preferredcodec"],
                        "preferredquality": quality_opts["preferredquality"],
                    },
                    {
                        "key": "FFmpegMetadata",
                        "add_metadata": True,
                    },
                ],
                "writethumbnail": True,
                "embedthumbnail": True,
                "postprocessor_args": [
                    "-metadata", f"title={task.title}",
                    "-metadata", f"artist={task.artist}",
                ],
            }
            
            # Download in thread pool
            def _download():
                print(f"[YT] Starting download for task {task_id}")
                with YoutubeDL(opts) as ydl:
                    ydl.download([url])
                print(f"[YT] Download complete for task {task_id}")
            
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(None, _download)
            print(f"[YT] Executor finished for task {task_id}")
            
            # Find the output file - check for any file with task_id prefix
            expected_ext = "m4a" if quality == "m4a" else "mp3"
            print(f"[YT] Looking for files in {DOWNLOAD_DIR} with prefix {task_id}")
            
            for filename in os.listdir(DOWNLOAD_DIR):
                print(f"[YT] Found file: {filename}")
                if filename.startswith(task_id) and filename.endswith(f".{expected_ext}"):
                    task.file_path = os.path.join(DOWNLOAD_DIR, filename)
                    task.file_size = os.path.getsize(task.file_path)
                    print(f"[YT] Matched file: {task.file_path} ({task.file_size} bytes)")
                    break
            
            if not task.file_path or not os.path.exists(task.file_path):
                print(f"[YT] ERROR: Could not find downloaded file for {task_id}")
                raise FileNotFoundError("Downloaded file not found")
            
            task.status = DownloadStatus.UPLOADING
            task.progress = 85
            print(f"[YT] Ready for upload: {task.file_path}")
            
            return task
            
        except Exception as e:
            if task.task_id in self._cancelled_tasks:
                task.status = DownloadStatus.CANCELLED
                task.error = "Cancelled by user"
                self._cancelled_tasks.discard(task.task_id)
            else:
                task.status = DownloadStatus.FAILED
                task.error = str(e)
            return task
    
    def cancel_download(self, task_id: str) -> bool:
        """Cancel a running download"""
        if task_id in _download_tasks:
            self._cancelled_tasks.add(task_id)
            return True
        return False
    
    def mark_completed(self, task_id: str, song_id: str, telegram_msg_id: int):
        """Mark a task as completed after Telegram upload"""
        if task_id in _download_tasks:
            task = _download_tasks[task_id]
            task.status = DownloadStatus.COMPLETED
            task.progress = 100
            task.song_id = song_id
            task.telegram_msg_id = telegram_msg_id
    
    def mark_failed(self, task_id: str, error: str):
        """Mark a task as failed"""
        if task_id in _download_tasks:
            task = _download_tasks[task_id]
            task.status = DownloadStatus.FAILED
            task.error = error
    
    def cleanup_task(self, task_id: str):
        """Clean up downloaded files for a task"""
        if task_id in _download_tasks:
            task = _download_tasks[task_id]
            if task.file_path and os.path.exists(task.file_path):
                try:
                    os.remove(task.file_path)
                except Exception:
                    pass
            # Also clean up any thumbnail files
            for f in os.listdir(DOWNLOAD_DIR):
                if f.startswith(task_id):
                    try:
                        os.remove(os.path.join(DOWNLOAD_DIR, f))
                    except Exception:
                        pass


def get_task(task_id: str) -> Optional[DownloadTask]:
    """Get a download task by ID"""
    return _download_tasks.get(task_id)


def get_all_tasks() -> Dict[str, DownloadTask]:
    """Get all download tasks"""
    return _download_tasks.copy()


# Singleton instance
youtube_downloader = YouTubeDownloader()
