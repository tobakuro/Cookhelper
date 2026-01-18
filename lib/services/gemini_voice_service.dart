import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 音声コマンドの種類
enum VoiceCommand {
  nextStep,
  prevStep,
  startTimer,
  stopTimer,
  pauseTimer,
  resumeTimer,
  addTimerTime,
  subtractTimerTime,
  repeatStep,
}

/// Gemini Live APIを使用したリアルタイム音声認識サービス
class GeminiVoiceService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  bool _isListening = false;
  String _lastCommand = '';
  String _statusMessage = '';

  /// 音声コマンドが認識された時のコールバック
  void Function(VoiceCommand command, {int? value})? onCommandReceived;

  bool get isListening => _isListening;
  String get lastCommand => _lastCommand;
  String get statusMessage => _statusMessage;

  /// Gemini Live APIに接続
  Future<void> _connectToGemini() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      _statusMessage = 'APIキーが設定されていません';
      notifyListeners();
      return;
    }

    final uri = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$apiKey');

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        try {
          String jsonString;
          if (message is Uint8List) {
            jsonString = utf8.decode(message);
          } else {
            jsonString = message;
          }

          final data = jsonDecode(jsonString);
          debugPrint("受信データ: $jsonString");

          // ToolCallが含まれているかチェック
          if (data['toolCall'] != null) {
            final calls = data['toolCall']['functionCalls'] as List;
            for (var call in calls) {
              _handleFunctionCall(call['name'], call['args']);
            }
          }
        } catch (e) {
          debugPrint("受信データ解析エラー: $e");
        }
      },
      onError: (error) {
        debugPrint("WebSocketエラー: $error");
        _statusMessage = '接続エラー: $error';
        notifyListeners();
      },
      onDone: () {
        debugPrint("WebSocket接続終了");
        _isListening = false;
        notifyListeners();
      },
    );

    // Geminiに送信するセットアップ
    final setup = {
      "setup": {
        "model": "models/gemini-2.0-flash-exp",
        "system_instruction": {
          "parts": [
            {
              "text": """あなたは料理アシスタントです。ユーザーの音声コマンドを認識し、適切な関数を呼び出してください。

コマンドの対応:
- 「次」「次へ」「進む」「ネクスト」→ next_step
- 「前」「戻る」「戻って」「バック」→ prev_step
- 「タイマー開始」「タイマースタート」「タイマーを始めて」→ start_timer
- 「タイマー停止」「タイマーストップ」「タイマーを止めて」「タイマーリセット」→ stop_timer
- 「一時停止」「ポーズ」→ pause_timer
- 「再開」「タイマー再開」→ resume_timer
- 「〇分追加」「〇秒追加」「〇分プラス」→ add_timer_time (秒数を指定)
- 「〇分減らして」「〇秒マイナス」→ subtract_timer_time (秒数を指定)
- 「もう一度」「繰り返して」「読んで」「リピート」→ repeat_step

余計な言葉は返さず、関数呼び出しのみを行ってください。"""
            }
          ]
        },
        "tools": [
          {
            "function_declarations": [
              {"name": "next_step", "description": "次の調理ステップに進みます"},
              {"name": "prev_step", "description": "前の調理ステップに戻ります"},
              {"name": "start_timer", "description": "タイマーを開始します"},
              {"name": "stop_timer", "description": "タイマーを停止・リセットします"},
              {"name": "pause_timer", "description": "タイマーを一時停止します"},
              {"name": "resume_timer", "description": "タイマーを再開します"},
              {
                "name": "add_timer_time",
                "description": "タイマーに時間を追加します",
                "parameters": {
                  "type": "object",
                  "properties": {
                    "seconds": {
                      "type": "integer",
                      "description": "追加する秒数"
                    }
                  },
                  "required": ["seconds"]
                }
              },
              {
                "name": "subtract_timer_time",
                "description": "タイマーから時間を減らします",
                "parameters": {
                  "type": "object",
                  "properties": {
                    "seconds": {
                      "type": "integer",
                      "description": "減らす秒数"
                    }
                  },
                  "required": ["seconds"]
                }
              },
              {"name": "repeat_step", "description": "現在のステップを読み上げます"}
            ]
          }
        ]
      }
    };
    _channel!.sink.add(jsonEncode(setup));
  }

  /// Function Callを処理
  void _handleFunctionCall(String name, Map<String, dynamic>? args) {
    _lastCommand = name;
    notifyListeners();

    VoiceCommand? command;
    int? value;

    switch (name) {
      case 'next_step':
        command = VoiceCommand.nextStep;
      case 'prev_step':
        command = VoiceCommand.prevStep;
      case 'start_timer':
        command = VoiceCommand.startTimer;
      case 'stop_timer':
        command = VoiceCommand.stopTimer;
      case 'pause_timer':
        command = VoiceCommand.pauseTimer;
      case 'resume_timer':
        command = VoiceCommand.resumeTimer;
      case 'add_timer_time':
        command = VoiceCommand.addTimerTime;
        value = args?['seconds'] as int?;
      case 'subtract_timer_time':
        command = VoiceCommand.subtractTimerTime;
        value = args?['seconds'] as int?;
      case 'repeat_step':
        command = VoiceCommand.repeatStep;
    }

    if (command != null) {
      debugPrint('音声コマンド実行: $command (value: $value)');
      onCommandReceived?.call(command, value: value);
    }
  }

  /// 音声入力開始
  Future<void> startListening() async {
    if (_isListening) return;

    if (!await _recorder.hasPermission()) {
      _statusMessage = 'マイクの使用許可が得られませんでした';
      notifyListeners();
      return;
    }

    if (_channel == null) {
      await _connectToGemini();
    }

    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));

      _isListening = true;
      _statusMessage = '音声認識中...';
      notifyListeners();

      stream.listen((Uint8List pcm) {
        if (_channel != null && _isListening) {
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
    } catch (e) {
      debugPrint('音声入力開始エラー: $e');
      _statusMessage = '音声入力エラー: $e';
      _isListening = false;
      notifyListeners();
    }
  }

  /// 音声入力停止
  Future<void> stopListening() async {
    await _recorder.stop();
    _isListening = false;
    _statusMessage = '音声認識停止';
    notifyListeners();
  }

  /// 接続を切断
  Future<void> disconnect() async {
    await stopListening();
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    disconnect();
    _recorder.dispose();
    super.dispose();
  }
}
