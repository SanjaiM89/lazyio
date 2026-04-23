from app.db.connection import tasks_collection
from datetime import datetime


def youtube_task_helper(task) -> dict:
    return {
        "id": str(task["_id"]),
        "task_id": task.get("task_id"),
        "url": task.get("url"),
        "status": task.get("status"),
        "progress": task.get("progress", 0),
        "title": task.get("title", ""),
        "artist": task.get("artist", ""),
        "thumbnail": task.get("thumbnail", ""),
        "duration": task.get("duration", 0),
        "file_size": task.get("file_size", 0),
        "error": task.get("error", ""),
        "quality": task.get("quality", "320"),
        "song_id": task.get("song_id"),
        "created_at": task.get("created_at"),
    }


async def save_youtube_task(task_data: dict) -> str:
    task_id = task_data.get("task_id")
    existing = await tasks_collection.find_one({"task_id": task_id})

    if existing:
        await tasks_collection.update_one({"task_id": task_id}, {"$set": task_data})
        return str(existing["_id"])
    else:
        task_data["created_at"] = datetime.utcnow()
        result = await tasks_collection.insert_one(task_data)
        return str(result.inserted_id)


async def get_youtube_task(task_id: str) -> dict:
    task = await tasks_collection.find_one({"task_id": task_id})
    if task:
        return youtube_task_helper(task)
    return None


async def get_youtube_tasks(page: int = 1, limit: int = 10) -> dict:
    skip = (page - 1) * limit
    total = await tasks_collection.count_documents({})

    tasks = []
    async for task in (
        tasks_collection.find().sort("created_at", -1).skip(skip).limit(limit)
    ):
        tasks.append(youtube_task_helper(task))

    return {
        "tasks": tasks,
        "page": page,
        "limit": limit,
        "total": total,
        "pages": (total + limit - 1) // limit if total > 0 else 1,
    }


async def update_youtube_task(task_id: str, updates: dict):
    await tasks_collection.update_one({"task_id": task_id}, {"$set": updates})


async def delete_youtube_task(task_id: str):
    await tasks_collection.delete_one({"task_id": task_id})


async def clear_all_youtube_tasks():
    result = await tasks_collection.delete_many({})
    return result.deleted_count
