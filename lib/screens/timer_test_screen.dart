import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AlarmTimer extends StatefulWidget {
  const AlarmTimer({super.key});

  @override
  State<AlarmTimer> createState() => _AlarmTimerState();
}

class _AlarmTimerState extends State<AlarmTimer> {
  final TextEditingController _timeController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _timer;
  int _remainingTime = 0;

  bool _isListening = false;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _speech.stop();
    _timeController.dispose();
    super.dispose();
  }

  /* ================= 音声認識 ================= */

  Future<void> _startListening() async {
    if (_isListening) return;

    final available = await _speech.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音声認識が利用できません')),
      );
      return;
    }

    setState(() => _isListening = true);

    _speech.listen(
      localeId: 'ja_JP',
      onResult: (result) {
        _processVoiceCommand(result.recognizedWords);
      },
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _processVoiceCommand(String text) {
    text = text.replaceAll(' ', '');

    if (text.contains('止めて') || text.contains('停止') || text.contains('ストップ')) {
      _stopAlarm();
      return;
    }

    if (text.contains('リセット')) {
      _resetTimer();
      return;
    }

    if (text.contains('スタート')) {
      _startTimer();
      return;
    }

    if (text.contains('追加')) {
      final sec = _parseTimeFromVoice(text);
      if (sec != null) {
        setState(() => _remainingTime += sec);
      }
      return;
    }

    final seconds = _parseTimeFromVoice(text);
    if (seconds != null) {
      _timeController.text = seconds.toString();
    }
  }

  int? _parseTimeFromVoice(String text) {
    int total = 0;

    final minMatch = RegExp(r'(\d+)分').firstMatch(text);
    final secMatch = RegExp(r'(\d+)秒').firstMatch(text);

    if (minMatch == null && secMatch == null) return null;

    if (minMatch != null) total += int.parse(minMatch.group(1)!) * 60;
    if (secMatch != null) total += int.parse(secMatch.group(1)!);

    return total;
  }

  /* ================= タイマー処理 ================= */

  void _startTimer() {
    if (_isRunning) return;

    final seconds = int.tryParse(_timeController.text);
    if (seconds == null || seconds <= 0) return;

    _stopListening();

    setState(() {
      _remainingTime = seconds;
      _isRunning = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          timer.cancel();
          _isRunning = false;
          _playAlarm();
        }
      });
    });
  }

  Future<void> _playAlarm() async {
    await _audioPlayer.stop();
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('alarm.mp3'));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⏰ タイマー終了！')),
    );
  }

  void _stopAlarm() {
    _timer?.cancel();
    _audioPlayer.stop();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _stopAlarm();
    setState(() {
      _remainingTime = 0;
      _timeController.clear();
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('音声アラームタイマー')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _timeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'タイマー時間（秒）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              '残り時間: ${_formatTime(_remainingTime)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(_isListening ? '音声入力停止' : '音声入力開始'),
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _isRunning ? null : _startTimer,
              child: const Text('スタート'),
            ),
            ElevatedButton(
              onPressed: _stopAlarm,
              child: const Text('停止'),
            ),
            ElevatedButton(
              onPressed: _resetTimer,
              child: const Text('リセット'),
            ),
          ],
        ),
      ),
    );
  }
}
