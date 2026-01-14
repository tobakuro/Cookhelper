import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class RokuonPage extends StatefulWidget {
  const RokuonPage({super.key});

  @override
  State<RokuonPage> createState() => _RokuonPageState();
}

class _RokuonPageState extends State<RokuonPage> {
  // 録音状態を管理するRecorderインスタンス
  final _audioRecorder = AudioRecorder();
  String? _audioPath;
  bool _isRecording = false;
  String _response = "ここにGeminiからの応答が表示されます。";

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // 録音開始
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appTempDir = await getTemporaryDirectory();
        // 録音ファイルのパスをユニークに設定
        _audioPath = '${appTempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

        // 録音設定
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000), // 品質向上のためsampleRateを追加
          path: _audioPath!,
        );

        setState(() {
          _isRecording = true;
          _response = "録音中...";
        });
      } else {
        setState(() {
          _response = "マイクの使用許可が得られませんでした。";
        });
      }
    } catch (e) {
      setState(() {
        _response = "録音開始エラー: $e";
      });
      debugPrint('録音開始エラー: $e');
    }
  }

  // 録音停止
  Future<void> _stopRecording() async {
    try {
      final String? path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _audioPath = path;
          _response = "録音が完了しました。音声を分析中...";
        });
        await _sendAudioToGemini(path);
      } else {
        setState(() {
          _isRecording = false;
          _response = "録音停止エラー: ファイルパスが取得できませんでした。";
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _response = "録音停止エラー: $e";
      });
      debugPrint('録音停止エラー: $e');
    }
  }

  // Geminiに音声を送信
  Future<void> _sendAudioToGemini(String path) async {
    try {

      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isEmpty) {
        setState(() {
          _response = "エラー: APIキーが設定されていません。（例: --dart-define=GEMINI_API_KEY=YOUR_KEY）";
        });
        return;
      }

      // 処理中のメッセージを更新
      setState(() {
        _response = "Geminiモデルが音声を分析しています...";
      });

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final audioFile = File(path);
      final audioBytes = await audioFile.readAsBytes();

      // AudioPartとTextPartの作成
      final audioPart = DataPart(
        'audio/aac', // 録音設定に合わせたMIMEタイプ
        Uint8List.fromList(audioBytes),
      );

      final promptPart = TextPart("この音声ファイルの内容を分析し、日本語で返答してください。");

      // ? 【修正箇所】Contentコンストラクタを (role, parts) の位置引数に変更し、型を明示する
      final List<Content> contents = [
        Content(
          'user', // 1. role ('user') を位置引数として渡す
          [ // 2. parts のリスト ([audioPart, promptPart]) を位置引数として渡す
            audioPart,
            promptPart,
          ],
        ),
      ];

      final response = await model.generateContent(contents);

      setState(() {
        _response = response.text ?? "Geminiからの応答がありませんでした。";
      });

      // 応答後、ファイルを削除
      audioFile.delete();

    } catch (e) {
      setState(() {
        _response = "Geminiとの通信エラー: $e";
      });
      debugPrint('Geminiエラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini音声分析'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 応答メッセージ表示エリア
              Card(
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 150),
                  child: SingleChildScrollView(
                    child: Text(
                      _response,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // 録音ボタン
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.redAccent : Colors.blueAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isRecording ? Colors.red.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.5),
                        spreadRadius: 5,
                        blurRadius: 7,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isRecording ? 'タップして録音を終了' : 'タップして録音を開始',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isRecording ? Colors.red : Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}