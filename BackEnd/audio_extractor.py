"""
Audio Extractor Module
Uses ffmpeg to extract audio from video files
"""

import os
import subprocess
import asyncio
from typing import Optional

# Temp directory for extracted audio
EXTRACT_DIR = os.path.join(os.path.dirname(__file__), "temp_uploads", "extracted")
os.makedirs(EXTRACT_DIR, exist_ok=True)


async def extract_audio_from_video(video_path: str, output_format: str = "mp3") -> Optional[str]:
    """
    Extract audio track from a video file using ffmpeg.
    
    Args:
        video_path: Path to the video file
        output_format: Audio format (default: mp3)
    
    Returns:
        Path to extracted audio file, or None if extraction failed
    """
    if not os.path.exists(video_path):
        print(f"[AUDIO_EXTRACTOR] Video file not found: {video_path}")
        return None
    
    # Generate output path
    base_name = os.path.splitext(os.path.basename(video_path))[0]
    output_path = os.path.join(EXTRACT_DIR, f"{base_name}.{output_format}")
    
    # ffmpeg command to extract audio
    cmd = [
        "ffmpeg",
        "-i", video_path,
        "-vn",  # No video
        "-acodec", "libmp3lame" if output_format == "mp3" else "aac",
        "-b:a", "192k",  # Bitrate
        "-y",  # Overwrite output
        output_path
    ]
    
    try:
        print(f"[AUDIO_EXTRACTOR] Extracting audio: {video_path} -> {output_path}")
        
        # Run ffmpeg asynchronously
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        stdout, stderr = await process.communicate()
        
        if process.returncode == 0 and os.path.exists(output_path):
            print(f"[AUDIO_EXTRACTOR] Audio extracted successfully: {output_path}")
            return output_path
        else:
            print(f"[AUDIO_EXTRACTOR] Extraction failed: {stderr.decode()}")
            return None
            
    except FileNotFoundError:
        print("[AUDIO_EXTRACTOR] ffmpeg not found. Please install ffmpeg.")
        return None
    except Exception as e:
        print(f"[AUDIO_EXTRACTOR] Error: {e}")
        return None


def cleanup_extracted_file(file_path: str):
    """Remove an extracted audio file"""
    try:
        if file_path and os.path.exists(file_path):
            os.remove(file_path)
            print(f"[AUDIO_EXTRACTOR] Cleaned up: {file_path}")
    except Exception as e:
        print(f"[AUDIO_EXTRACTOR] Cleanup error: {e}")
