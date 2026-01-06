import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleLiveAPITestScreen extends StatefulWidget {
  const GoogleLiveAPITestScreen({super.key});

  @override
  State<GoogleLiveAPITestScreen> createState() => _GoogleLiveAPITestScreenState();
}

class _GoogleLiveAPITestScreenState extends State<GoogleLiveAPITestScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  bool _isListening = false;
  int _value = 0;
  String _lastCommand = '---';

  @override
  void dispose() {
    _recorder.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  // ===== Gemini Live APIに接続 =====
  Future<void> _connectToGemini() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$apiKey');

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen((message) {
      try {
        String jsonString;
        if (message is Uint8List) {
          jsonString = utf8.decode(message);
        } else {
          jsonString = message;
        }

        final data = jsonDecode(jsonString);
        
        // デバッグ用にログを出すと安心です
        debugPrint("受信データ: $jsonString");

        // ToolCallが含まれているかチェック
        if (data['toolCall'] != null) {
          final calls = data['toolCall']['functionCalls'] as List;
          for (var call in calls) {
            _handleVoiceCommand(call['name']);
          }
        }
      } catch (e) {
        debugPrint("受信データ解析エラー: $e");
      }
    });

    // --- ここが重要：Geminiへの強力な指示を追加 ---
    final setup = {
      "setup": {
        "model": "models/gemini-2.0-flash-exp",
        "system_instruction": {
          "parts": [
            {
              "text": "あなたは数値操作アシスタントです。ユーザーが『次』『進む』『プラス』などの意図を示したら、必ず『next』関数を呼び出してください。余計な言葉は一切返さず、関数呼び出しのみを行ってください。何回続いても同じです。"
            }
          ]
        },
        "tools": [{
          "function_declarations": [
            {"name": "next", "description": "数値を1増やします。"},
            {"name": "prev", "description": "数値を1減らします。"}
          ]
        }]
      }
    };
    _channel!.sink.add(jsonEncode(setup));
  }

  // ===== 音声入力開始 =====
  Future<void> _startListening() async {
    if (!await _recorder.hasPermission()) return;

    if (_channel == null) {
      await _connectToGemini();
    }

    // recordパッケージ最新版の書き方
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits, 
      sampleRate: 16000,
      numChannels: 1,
    ));

    setState(() {
      _isListening = true;
    });

    stream.listen((Uint8List pcm) {
      if (_channel != null) {
        final b64Data = base64Encode(pcm);
        final audioMessage = {
          "realtime_input": {
            "media_chunks": [
              {"data": b64Data, "mime_type": "audio/pcm"}
            ]
          }
        };
        _channel!.sink.add(jsonEncode(audioMessage));
      }
    });
  }

  Future<void> _stopListening() async {
    await _recorder.stop();
    setState(() => _isListening = false);
  }

  void _handleVoiceCommand(String intent) {
    setState(() {
      _lastCommand = intent;
      if (intent == 'next') _value++;
      if (intent == 'prev') _value--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Live 操作テスト')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('現在の数値', style: TextStyle(fontSize: 16)),
            Text('$_value', style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold)),
            Text('最後の命令: $_lastCommand'),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _isListening ? _stopListening : _startListening,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: _isListening ? Colors.red : Colors.blue,
                child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}