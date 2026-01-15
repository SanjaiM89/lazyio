import 'dart:async';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import '../widgets/glass_container.dart';
import '../constants.dart';

class YouTubeScreen extends StatefulWidget {
  final String? initialQuery;
  const YouTubeScreen({super.key, this.initialQuery});

  @override
  State<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<YouTubeScreen> {
  final TextEditingController _urlController = TextEditingController();
  List<YouTubeTask> _tasks = [];
  bool _loading = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _handleInitialQuery();
    _loadTasks();
    _startPolling();
  }

  @override
  void didUpdateWidget(YouTubeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery && widget.initialQuery != null) {
      _handleInitialQuery();
    }
  }

  void _handleInitialQuery() {
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      String q = widget.initialQuery!;
      // Simple play/url check
      if (!q.startsWith('http') && !q.startsWith('www.') && !q.startsWith('ytsearch')) {
        q = 'ytsearch1:$q';
      }
      _urlController.text = q;
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Only poll if there are non-terminal tasks
      if (_tasks.any((t) => ['pending', 'downloading', 'processing', 'uploading'].contains(t.status))) {
        _loadTasks();
      }
    });
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await ApiService.getYoutubeTasks(limit: 50);
      if (mounted) {
        setState(() {
          _tasks = tasks;
        });
      }
    } catch (e) {
      print("Error loading tasks: $e");
    }
  }

  Future<void> _submitDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _loading = true);
    try {
      await ApiService.submitYoutubeUrl(url, '320'); // Default high quality
      _urlController.clear();
      _loadTasks(); // Immediate refresh
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
           Container(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("YouTube To MP3", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    if (_tasks.isNotEmpty)
                      TextButton.icon(
                        onPressed: () async {
                          await ApiService.clearAllYoutubeTasks();
                          _loadTasks();
                        },
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text("Clear All"),
                        style: TextButton.styleFrom(foregroundColor: Colors.white54),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Paste YouTube Link",
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _loading ? null : _submitDownload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kPrimaryColor, kSecondaryColor]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _loading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return _buildTaskItem(task);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(YouTubeTask task) {
    Color statusColor = Colors.white54;
    IconData statusIcon = Icons.schedule;
    
    switch (task.status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'downloading':
      case 'processing':
      case 'uploading':
        statusColor = kPrimaryColor;
        statusIcon = Icons.downloading;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title ?? task.url,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!['completed', 'failed', 'cancelled'].contains(task.status))
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white38, size: 20),
                    onPressed: () => ApiService.cancelYoutubeTask(task.taskId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (['downloading', 'uploading', 'processing'].contains(task.status)) ...[
              LinearProgressIndicator(
                value: task.progress / 100, // Assuming 0-100
                backgroundColor: Colors.white10,
                color: statusColor,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(task.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10)),
                  Text("${task.progress.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              )
            ] else 
              Text(
                task.status == 'failed' ? "Error: ${task.error}" : "Ready",
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
