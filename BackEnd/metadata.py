import os
import shutil
import asyncio
from mutagen import File
from mutagen.mp3 import MP3
from mutagen.flac import FLAC
from mutagen.id3 import ID3, TIT2, TPE1, TALB, APIC
from shazamio import Shazam

async def extract_metadata(file_path: str) -> dict:
    """
    Extracts metadata from a music file.
    Returns dict: {title, artist, album, duration, cover_art_path}
    """
    metadata = {
        "title": os.path.basename(file_path),
        "artist": "Unknown Artist",
        "album": "Unknown Album",
        "duration": 0,
        "cover_art": None
    }
    
    try:
        audio = File(file_path)
        if not audio:
            return metadata

        # Duration
        if hasattr(audio, 'info') and hasattr(audio.info, 'length'):
            metadata["duration"] = int(audio.info.length)

        # ID3/Tags (Basic)
        if isinstance(audio, MP3) or isinstance(audio, ID3):
             tags = audio.tags
             if tags:
                 if 'TIT2' in tags: metadata["title"] = str(tags['TIT2'])
                 if 'TPE1' in tags: metadata["artist"] = str(tags['TPE1'])
                 if 'TALB' in tags: metadata["album"] = str(tags['TALB'])
        elif isinstance(audio, FLAC):
            if 'title' in audio: metadata["title"] = audio['title'][0]
            if 'artist' in audio: metadata["artist"] = audio['artist'][0]
            if 'album' in audio: metadata["album"] = audio['album'][0]

        # ENHANCEMENT: Use Shazam to get high quality Cover Art and better Metadata
        # This solves the "missing image" issue on ephemeral hosting
        try:
            print(f"[Metadata] Running Shazam for: {metadata['title']}")
            shazam = Shazam()
            out = await shazam.recognize_song(file_path)
            
            if out and 'track' in out:
                track = out['track']
                # Prefer Shazam metadata if available, as it's cleaner
                if 'title' in track: metadata["title"] = track['title']
                if 'subtitle' in track: metadata["artist"] = track['subtitle']
                
                # Get Cover Art
                if 'images' in track and 'coverart' in track['images']:
                    metadata["cover_art"] = track['images']['coverart']
                    print(f"[Metadata] Found cover art: {metadata['cover_art']}")
                elif 'images' in track and 'background' in track['images']:
                    metadata["cover_art"] = track['images']['background']
                    
                # Store full data for future use?
                # metadata["shazam_data"] = track 
        except Exception as es:
            print(f"[Metadata] Shazam lookup failed: {es}")

    except Exception as e:
        print(f"Error extracting metadata for {file_path}: {e}")
        
    return metadata

async def recognize_song(file_path: str):
    """
    Uses ShazamIO to recognize a song.
    """
    try:
        shazam = Shazam()
        out = await shazam.recognize_song(file_path)
        return out
    except Exception as e:
        print(f"Shazam error: {e}")
        return None
