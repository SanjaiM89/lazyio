import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../api_service.dart';
import '../widgets/glass_container.dart';
import '../constants.dart';

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
        const SnackBar(content: Text('Upload Successful'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeFile(PlatformFile file) {
    setState(() {
      _files.remove(file);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Upload Music", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Add files from your device", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),
            
            // Upload Area
            GestureDetector(
              onTap: _uploading ? null : _pickFiles,
              child: GlassContainer(
                height: 200,
                padding: const EdgeInsets.all(0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 60, color: _uploading ? Colors.white38 : kPrimaryColor),
                      const SizedBox(height: 16),
                      Text(
                        _uploading ? "Uploading..." : "Tap to Select Files",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      if (!_uploading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text("Supports MP3, FLAC, WAV", style: TextStyle(color: Colors.white38)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            if (_statusMessage != null) ...[
               const SizedBox(height: 16),
               Center(child: Text(_statusMessage!, style: TextStyle(color: _statusMessage!.startsWith("Error") ? Colors.red : Colors.green))),
            ],

            const SizedBox(height: 24),
            
            // File List
            if (_files.isNotEmpty) ...[
              const Text("Selected Files", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.audio_file, color: Colors.white54),
                        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text("${(file.size / 1024 / 1024).toStringAsFixed(2)} MB", style: const TextStyle(fontSize: 12, color: Colors.white38)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white38),
                          onPressed: () => _removeFile(file),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _uploading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                      : const Text("Start Upload", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 80), // Padding for nav bar
            ],
          ],
        ),
      ),
    );
  }
}
