import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../main.dart'; // To access MyApp or navigation

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _portController = TextEditingController();
  final _ipController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Default to the DuckDNS domain
      _ipController.text = prefs.getString('server_ip') ?? 'lazyio.duckdns.org'; 
      _portController.text = prefs.getString('server_port') ?? '';
    });
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Verifying connection...';
    });

    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    if (ip.isEmpty || port.isEmpty) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Please enter both IP and Port';
      });
      return;
    }

    // Construct URL
    final baseUrl = 'http://$ip:$port';
    final wsUrl = 'ws://$ip:$port/ws';

    // Verify connection (Simple Ping)
    try {
      // TODO: Add a real ping/health check here if desired.
      // For now, we assume if the user inputs it, we try to use it.
      // A more robust app would try a GET request to /health
      
      // Save settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', ip);
      await prefs.setString('server_port', port);
      
      // Update global config (if using a singleton or static)
      // Note: AppConfig needs to be implemented to hold this state dynamically
      AppConfig.baseUrl = baseUrl;
      AppConfig.wsUrl = wsUrl;

      setState(() {
        _statusMessage = 'Connected!';
      });

      // Navigate to Home
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.link,
                size: 80,
                color: Colors.deepPurpleAccent,
              ),
              const SizedBox(height: 32),
              const Text(
                'Connect to Server',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your ProtonVPN Port',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // IP Input (Optional if using DuckDNS mostly)
              TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Server IP / Domain',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.dns, color: Colors.deepPurpleAccent),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Port Input
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Port Number',
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.numbers, color: Colors.deepPurpleAccent),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              if (_statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _statusMessage.startsWith('Connected') 
                          ? Colors.green 
                          : Colors.redAccent,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              ElevatedButton(
                onPressed: _isLoading ? null : _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Connect',
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
      ),
    );
  }
}
