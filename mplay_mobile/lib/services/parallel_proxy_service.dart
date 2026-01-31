import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class ParallelProxyService {
  static final ParallelProxyService _instance = ParallelProxyService._internal();
  factory ParallelProxyService() => _instance;
  ParallelProxyService._internal();

  HttpServer? _server;
  int _port = 0;
  final Dio _dio = Dio();

  int get port => _port;

  /// Starts the local proxy server on an ephemeral port.
  Future<void> start() async {
    if (_server != null) return;

    try {
      // Bind to localhost on any available port (0)
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      print("🚀 Local Parallel Proxy running on http://127.0.0.1:$_port");

      _server!.listen((HttpRequest request) {
        _handleRequest(request);
      });
    } catch (e) {
      print("❌ Failed to start proxy: $e");
    }
  }

  /// Stops the server
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  /// Generates a proxy URL for the given target URL
  String getProxyUrl(String targetUrl) {
    if (_port == 0) return targetUrl; // Fallback if server not running
    // Encode the target URL to be safe
    final encodedUrl = Uri.encodeComponent(targetUrl);
    return "http://127.0.0.1:$_port/stream?url=$encodedUrl";
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final targetUrlParam = request.uri.queryParameters['url'];
    if (targetUrlParam == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write("Missing 'url' parameter");
      await request.response.close();
      return;
    }

    final String targetUrl = Uri.decodeComponent(targetUrlParam);
    final String? rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

    print("[Proxy] Requesting: $targetUrl | Range: $rangeHeader");

    try {
      // 1. Get File Size (Head Request)
      // We need size to calculate chunks
      final headResponse = await _dio.head(targetUrl);
      final int fileSize = int.parse(headResponse.headers.value(HttpHeaders.contentLengthHeader) ?? "0");
      
      if (fileSize == 0) {
         // Fallback to direct redirect if size unknown
         request.response.redirect(Uri.parse(targetUrl));
         return;
      }

      int start = 0;
      int end = fileSize - 1;

      if (rangeHeader != null) {
        final parts = rangeHeader.replaceFirst("bytes=", "").split("-");
        start = int.parse(parts[0]);
        if (parts.length > 1 && parts[1].isNotEmpty) {
          end = int.parse(parts[1]);
        }
      }

      final int totalLength = end - start + 1;

      // Response Headers
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(HttpHeaders.contentLengthHeader, totalLength);
      request.response.headers.set(HttpHeaders.contentRangeHeader, "bytes $start-$end/$fileSize");
      request.response.headers.set(HttpHeaders.acceptRangesHeader, "bytes");
      request.response.headers.set(HttpHeaders.contentTypeHeader, "video/mp4"); // Generic or detect

      // 2. Parallel Download Logic
      // If request is small (< 1MB), do single connection
      if (totalLength < 1024 * 1024) {
         await _streamSingle(targetUrl, start, end, request.response);
      } else {
         await _streamParallel(targetUrl, start, end, totalLength, request.response);
      }

    } catch (e) {
      print("[Proxy Error] $e");
      if (!request.response.headers.chunkedTransferEncoding) {
         request.response.statusCode = HttpStatus.internalServerError;
      }
    } finally {
      await request.response.close();
    }
  }

  Future<void> _streamSingle(String url, int start, int end, HttpResponse response) async {
    try {
        final resp = await _dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: {HttpHeaders.rangeHeader: "bytes=$start-$end"},
          ),
        );
        // await resp.data!.stream.pipe(response);
        await response.addStream(resp.data!.stream);
    } catch (e) {
        print("Single Stream Error: $e");
    }
  }
  
  /// The Core Logic: Parallel Downloading
  Future<void> _streamParallel(String url, int start, int end, int totalLength, HttpResponse response) async {
    // Determine chunks (4 Concurrent)
    int workers = 4;
    int chunkSize = (totalLength / workers).ceil();

    List<Future<List<int>>> futures = [];
    
    // NOTE: We cannot simply pipe 4 streams to one response sequentially unless we await them in order.
    // Ideally, we want to write to the response AS they arrive.
    // However, writing to HttpResponse is sequential. 
    // If Part 2 arrives before Part 1, we CANNOT write Part 2 yet.
    
    // Strategy: 
    // 1. Start all 4 downloads.
    // 2. Buffer them (careful with memory!).
    // 3. Write them in order.
    
    // Optimization: Buffer size is critical. If file is 1GB, we can't buffer 250MB.
    // Real IDM writes to DISK. We are streaming to PLAYER.
    // Player needs sequential bytes (usually).
    
    // If we wait for Chunk 0 to finish before *requesting* Chunk 1, that's sequential.
    // If we request all, but wait to write, we hold connections open.
    
    // "Running Start" Strategy adapted for Dart:
    // We launch 4 streams. We read from Stream 0 and write.
    // Meanwhile Stream 1, 2, 3 are filling their internal buffers (TCP Window).
    // When Stream 0 ends, we switch to Stream 1.
    
    // Create requests
    List<Response<ResponseBody>> responses = [];
    
    for (int i = 0; i < workers; i++) {
        int chunkStart = start + (i * chunkSize);
        int chunkEnd = (i == workers - 1) ? end : chunkStart + chunkSize - 1;
        
        if (chunkStart > end) break; 
        
        // print("[Proxy] Worker $i: $chunkStart - $chunkEnd");
        
        // Launch Request (Async)
        final futureResp = _dio.get<ResponseBody>(
          url,
          options: Options(
            responseType: ResponseType.stream,
            headers: {HttpHeaders.rangeHeader: "bytes=$chunkStart-$chunkEnd"},
          ),
        );
        
        // We await the HEADER response, not the body completion
        responses.add(await futureResp); 
    }

    // Process Sequentially (but download is happening in background via OS TCP buffers)
    for (int i = 0; i < responses.length; i++) {
        // print("[Proxy] Writing Worker $i stream...");
        Stream<Uint8List> stream = responses[i].data!.stream;
        
        await for (var chunk in stream) {
            response.add(chunk);
            // Optionally flush?
            // await response.flush(); 
        }
    }
  }
}
