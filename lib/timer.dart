import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AlarmTimer extends StatefulWidget {
  const AlarmTimer({super.key});

  @override
  _AlarmTimerState createState() => _AlarmTimerState();
}

class _AlarmTimerState extends State<AlarmTimer> {
  final TextEditingController _timeController = TextEditingController();
  Timer? _timer;
  int _remainingTime = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    final input = _timeController.text;
    final seconds = int.tryParse(input);

    if (seconds == null || seconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効な秒数を入力してください')),
      );
      return;
    }

    setState(() {
      _remainingTime = seconds;
    });

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
    // アラーム音再生（必要ならパス変更）
    await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
  }

  void _stopAlarm() {
    _audioPlayer.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アラームタイマー'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
            ElevatedButton(
              onPressed: _startTimer,
              child: const Text('スタート'),
            ),
            const SizedBox(height: 10),
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
