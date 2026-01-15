import 'package:web_socket_channel/web_socket_channel.dart';
import 'constants.dart';

class WebSocketService {
  late WebSocketChannel _channel;
  Function(dynamic)? onMessage;

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel.stream.listen(
        (message) {
          if (onMessage != null) {
            onMessage!(message);
          }
        },
        onError: (error) => print('WS Error: $error'),
        onDone: () => print('WS Closed'),
      );
    } catch (e) {
      print('WS Connection Failed: $e');
    }
  }

  void close() {
    _channel.sink.close();
  }
}
