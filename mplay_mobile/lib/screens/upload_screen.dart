import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../api_service.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';
import 'search_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<PlatformFile> _files = [];
  bool _uploading = false;
  String? _statusMessage;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.audio,
      );

      if (result != null) {
        setState(() {
          _files = result.files;
          _statusMessage = null;
        });
      }
    } catch (e) {
      print("Error picking files: $e");
    }
  }

  Future<void> _upload() async {
    if (_files.isEmpty) return;

    setState(() {
      _uploading = true;
      _statusMessage = "Uploading ${_files.length} files...";
    });

    try {
      final paths = _files.map((f) => f.path!).toList();
      await ApiService.uploadFiles(paths);

      setState(() {
        _statusMessage = "Upload Complete!";
        _files = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload Successful')),
      );
    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeFile(PlatformFile file) {
    setState(() => _files.remove(file));
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Nocturne.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Upload to Telegram",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              const Text("Files go straight to your Telegram channel library",
                  style: TextStyle(fontSize: 13, color: Nocturne.onSurfaceVariant)),
              const SizedBox(height: 12),
              TopSearchBar(
                onSubmit: (q) => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SearchScreen(initialQuery: q))),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _uploading ? null : _pickFiles,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Nocturne.surfaceLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Nocturne.border),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 56,
                            color: _uploading ? Nocturne.outline : Nocturne.primary),
                        const SizedBox(height: 14),
                        Text(
                          _uploading ? "Uploading..." : "Tap to Select Files",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 17, color: Colors.white),
                        ),
                        if (!_uploading)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text("Supports MP3, FLAC, WAV",
                                style: TextStyle(color: Nocturne.outline, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 14),
                Center(
                  child: Text(_statusMessage!,
                      style: TextStyle(
                          color: _statusMessage!.startsWith("Error")
                              ? Colors.redAccent
                              : Nocturne.primary,
                          fontSize: 13)),
                ),
              ],
              const SizedBox(height: 20),
              if (_files.isNotEmpty) ...[
                const SectionHeader(title: 'Selected Files'),
                ..._files.map((file) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Nocturne.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          leading: const Icon(Icons.audio_file_rounded,
                              color: Nocturne.onSurfaceVariant),
                          title: Text(file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: Text(
                              "${(file.size / 1024 / 1024).toStringAsFixed(2)} MB",
                              style: const TextStyle(fontSize: 12, color: Nocturne.outline)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Nocturne.outline),
                            onPressed: () => _removeFile(file),
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _uploading ? null : _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Nocturne.primaryContainer,
                      foregroundColor: Nocturne.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: _uploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Nocturne.onPrimary))
                        : const Text("Start Upload",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
