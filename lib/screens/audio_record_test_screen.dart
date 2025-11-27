import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';

class AudioRecordTestScreen extends StatefulWidget {
  const AudioRecordTestScreen({super.key});

  @override
  State<AudioRecordTestScreen> createState() => _AudioRecordTestScreenState();
}

class _AudioRecordTestScreenState extends State<AudioRecordTestScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String _recordingPath = '';
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    // 再生状態のリスナーを設定
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        setState(() {
          _statusMessage = 'マイクの権限が必要です';
        });
        return;
      }
    }
    setState(() {
      _statusMessage = 'マイクの権限が許可されました';
    });
  }

  Future<void> _startRecording() async {
    try {
      // 権限チェック
      if (await _audioRecorder.hasPermission()) {
        String filePath;

        if (kIsWeb) {
          // Web環境: 仮想パスを使用
          filePath = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';

          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 44100,
              bitRate: 128000,
            ),
            path: filePath,
          );
          setState(() {
            _isRecording = true;
            _statusMessage = '録音中... (Web環境)';
          });
        } else {
          // Android/iOS環境: ファイルパスを指定
          final directory = await getApplicationDocumentsDirectory();
          filePath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              sampleRate: 44100,
              bitRate: 128000,
            ),
            path: filePath,
          );
          setState(() {
            _isRecording = true;
            _statusMessage = '録音中... (モバイル環境)';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'マイクの権限がありません';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'エラー: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingPath = path ?? '';

        if (kIsWeb) {
          _statusMessage = _recordingPath.isNotEmpty
              ? '録音完了！\nWeb環境: データはメモリに保存されました\n「再生」ボタンで確認できます'
              : '録音に失敗しました';
        } else {
          _statusMessage = _recordingPath.isNotEmpty
              ? '録音完了！\n保存先: $_recordingPath\n「再生」ボタンで確認できます'
              : '録音に失敗しました';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'エラー: $e';
        _isRecording = false;
      });
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath.isEmpty) {
      setState(() {
        _statusMessage = '再生する録音がありません';
      });
      return;
    }

    try {
      if (kIsWeb) {
        // Web環境: DeviceFileSourceを使用
        await _audioPlayer.play(DeviceFileSource(_recordingPath));
      } else {
        // Android/iOS環境: DeviceFileSourceを使用
        await _audioPlayer.play(DeviceFileSource(_recordingPath));
      }
      setState(() {
        _statusMessage = '再生中...';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '再生エラー: $e';
      });
    }
  }

  Future<void> _stopPlaying() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _statusMessage = '再生停止';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '停止エラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音声録音テスト'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              size: 100,
              color: _isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 32),
            Text(
              _isRecording ? '録音中...' : '録音停止中',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _isRecording ? Colors.red : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              kIsWeb ? 'プラットフォーム: Web' : 'プラットフォーム: モバイル',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _checkPermission,
              icon: const Icon(Icons.security),
              label: const Text('マイク権限を確認'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isRecording ? null : _startRecording,
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('録音開始'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isRecording ? _stopRecording : null,
              icon: const Icon(Icons.stop),
              label: const Text('録音停止'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: (_recordingPath.isNotEmpty && !_isPlaying) ? _playRecording : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('再生'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isPlaying ? _stopPlaying : null,
              icon: const Icon(Icons.stop),
              label: const Text('再生停止'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ステータス:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage.isEmpty
                        ? 'まず権限を確認してください'
                        : _statusMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: _statusMessage.contains('エラー')
                          ? Colors.red
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
