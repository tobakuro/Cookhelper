import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AlarmTimer extends StatefulWidget {
  const AlarmTimer({super.key});

  @override
  _AlarmTimerState createState() => _AlarmTimerState();
}

class _AlarmTimerState extends State<AlarmTimer> {
  final TextEditingController _timeController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  Timer? _timer;
  int _remainingTime = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isListening = false;

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('音声認識が利用できません')),
      );
      return;
    }

    setState(() => _isListening = true);

    _speech.listen(
      localeId: "ja_JP",
      onResult: (result) {
        _processVoiceCommand(result.recognizedWords);
      },
    );
  }

  void _processVoiceCommand(String text) {
    text = text.replaceAll(" ", "");

    if (text.contains("止めて") ||
        text.contains("停止") ||
        text.contains("ストップ")) {
      _stopAlarm();
      return;
    }

    final seconds = _parseTimeFromVoice(text);
    if (seconds != null) {
      _timeController.text = seconds.toString();
    }
  }

  int? _parseTimeFromVoice(String text) {
    int total = 0;

    final minRegex = RegExp(r'(\d+)分');
    final secRegex = RegExp(r'(\d+)秒');

    final minMatch = minRegex.firstMatch(text);
    final secMatch = secRegex.firstMatch(text);

    if (minMatch == null && secMatch == null) return null;

    if (minMatch != null) total += int.parse(minMatch.group(1)!) * 60;
    if (secMatch != null) total += int.parse(secMatch.group(1)!);

    return total;
  }

  void _startTimer() {
    final seconds = int.tryParse(_timeController.text);
    if (seconds == null || seconds <= 0) return;

    setState(() => _remainingTime = seconds);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          timer.cancel();
          _playAlarm();
        }
      });
    });
  }

  Future<void> _playAlarm() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('alarm.mp3'));
  }

  void _stopAlarm() {
    _audioPlayer.stop();
  }

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
              '残り時間: $_remainingTime 秒',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _startListening,
              icon: const Icon(Icons.mic),
              label: const Text('音声入力開始'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startTimer,
              child: const Text('スタート'),
            ),
            ElevatedButton(
              onPressed: _stopAlarm,
              child: const Text('アラーム停止'),
            ),
          ],
        ),
      ),
    );
  }
}
