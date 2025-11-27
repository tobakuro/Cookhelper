import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gemini_live/gemini_live.dart';
import 'package:flutter/foundation.dart';

class GeminiLiveService {
  // ignore: prefer_typing_uninitialized_variables, strict_top_level_inference
  final genAI;
  LiveSession? session;

  // 1. Initialize with API key
  GeminiLiveService() : genAI = dotenv.get('GEMINI_API_KEY', fallback: '') {
    if (genAI.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
  }

  // 2. Connect to the Live API
  Future<void> connect() async {
    try {
      session = await genAI.live.connect(
        model: 'gemini-2.0-flash-live-001',
        callbacks: LiveCallbacks(
          onOpen: () => debugPrint('✅ Connection opened'),
          onMessage: (LiveServerMessage message) {
            // 3. Handle incoming messages from the model
            if (message.text != null) {
              debugPrint('Received chunk: ${message.text}');
            }
            if (message.serverContent?.turnComplete ?? false) {
              debugPrint('✅ Turn complete!');
            }
          },
          onError: (e, s) => debugPrint('🚨 Error: $e'),
          onClose: (code, reason) => debugPrint('🚪 Connection closed'),
        ),
      );
    } catch (e) {
      debugPrint('Failed to connect: $e');
    }
  }

  // メッセージ送信
  void sendMessage(String text) {
  session?.sendMessage(
    LiveClientMessage(
      clientContent: LiveClientContent(
        turns: [
          Content(
            role: "user",
            parts: [Part(text: text)],
          ),
        ],
        turnComplete: true,
      ),
    ),
  );
}

  // 接続終了
  Future<void> disconnect() async {
    await session?.close();
    session = null;
  }
}