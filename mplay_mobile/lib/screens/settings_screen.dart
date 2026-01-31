import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _portController = TextEditingController();
  final _domainController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _statusMessage = '';
  String _serverIp = '';
  String _lastUpdated = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // First load local settings
      final prefs = await SharedPreferences.getInstance();
      _domainController.text = prefs.getString('server_ip') ?? 'lazyio.duckdns.org';
      _portController.text = prefs.getString('server_port') ?? '';
      
      // Then try to fetch from server
      await _fetchFromServer();
    } catch (e) {
      print('Error loading settings: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _fetchFromServer() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/connection-info'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _serverIp = data['ip'] ?? 'Unknown';
          if (data['port'] != null && data['port'].toString().isNotEmpty) {
            _portController.text = data['port'].toString();
          }
          if (data['updated_at'] != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch(
              (data['updated_at'] * 1000).toInt()
            );
            _lastUpdated = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}';
          }
        });
      }
    } catch (e) {
      print('Could not fetch from server: $e');
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _statusMessage = '';
    });

    final domain = _domainController.text.trim();
    final port = _portController.text.trim();

    if (port.isEmpty) {
      setState(() {
        _isSaving = false;
        _statusMessage = 'Please enter a port number';
      });
      return;
    }

    try {
      // Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', domain);
      await prefs.setString('server_port', port);

      // Update global config
      AppConfig.baseUrl = 'http://$domain:$port';
      AppConfig.wsUrl = 'ws://$domain:$port/ws';

      // Try to update on server (optional, may fail if port changed)
      try {
        await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/connection-info/port'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'port': port}),
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        // Ignore server update errors
      }

      setState(() {
        _statusMessage = 'Settings saved!';
      });

      // Go back after short delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
      
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Server Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Server Info Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.cloud_done, color: Colors.green),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Server Status',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _serverIp.isNotEmpty ? 'Connected ($_serverIp)' : 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_lastUpdated.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Last updated: $_lastUpdated',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Domain Input
                  const Text(
                    'Server Domain',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _domainController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'lazyio.duckdns.org',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.dns, color: Colors.deepPurpleAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Port Input
                  const Text(
                    'Port Number',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Enter port from Telegram',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 16),
                      prefixIcon: const Icon(Icons.numbers, color: Colors.deepPurpleAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Help text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Check Telegram for the latest port number when VPN reconnects.',
                            style: TextStyle(color: Colors.blue, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  if (_statusMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusMessage.contains('saved') ? Colors.green : Colors.redAccent,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  // Save Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
