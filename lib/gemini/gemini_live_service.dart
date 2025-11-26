import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gemini_live/gemini_live.dart';

class GeminiLiveService {
  late final GoogleGenAI _genAI;
  LiveSession? _session;
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  final StringBuffer _currentResponseBuffer = StringBuffer();

  GeminiLiveService() {
    final apiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
    _genAI = GoogleGenAI(apiKey: apiKey);
  }

  /// レスポンスのストリーム（双方向通信用）
  Stream<String> get responseStream => _responseController.stream;

  /// 双方向ライブセッションの開始
  Future<void> startLiveSession() async {
    try {
      if (_session != null) {
        throw Exception('Live session already active');
      }

      _currentResponseBuffer.clear();

      _session = await _genAI.live.connect(
        LiveConnectParameters(
          model: 'gemini-2.0-flash-live-001',
          callbacks: LiveCallbacks(
            onOpen: () {
              _responseController.add('[CONNECTED]');
            },
            onMessage: (LiveServerMessage message) {
              // テキストチャンクをストリームに配信
              if (message.text != null && message.text!.isNotEmpty) {
                _currentResponseBuffer.write(message.text);
                _responseController.add(message.text!);
              }

              // ターン完了の通知
              if (message.serverContent?.turnComplete ?? false) {
                _responseController.add('[TURN_COMPLETE]');
                _currentResponseBuffer.clear();
              }
            },
            onError: (e, s) {
              _responseController.addError(e);
            },
            onClose: (code, reason) {
              _responseController.add('[DISCONNECTED]');
            },
          ),
        ),
      );

      // 接続が確立されるまで少し待つ
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      throw Exception('Failed to start live session: $e');
    }
  }

  /// ライブセッションでメッセージを送信
  Future<void> sendMessage(String message) async {
    if (_session == null) {
      throw Exception('Live session not active. Call startLiveSession() first.');
    }

    try {
      _currentResponseBuffer.clear();

      _session!.sendMessage(
        LiveClientMessage(
          clientContent: LiveClientContent(
            turns: [
              Content(
                role: "user",
                parts: [Part(text: message)],
              ),
            ],
            turnComplete: true,
          ),
        ),
      );
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  /// ライブセッションの終了
  Future<void> endLiveSession() async {
    try {
      await _session?.close();
      _session = null;
      _currentResponseBuffer.clear();
    } catch (e) {
      throw Exception('Failed to end live session: $e');
    }
  }

  /// リソースのクリーンアップ
  void dispose() {
    _session?.close();
    _responseController.close();
    _currentResponseBuffer.clear();
  }
}
