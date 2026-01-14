import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerService extends ChangeNotifier {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  bool _isRunning = false;
  bool _isFinished = false;
  VoidCallback? onTimerComplete;

  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  bool get isRunning => _isRunning;
  bool get isFinished => _isFinished;

  String get displayTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get progress {
    if (_totalSeconds == 0) return 0.0;
    return (_totalSeconds - _remainingSeconds) / _totalSeconds;
  }

  void startTimer(int seconds) {
    stopTimer();
    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    _isRunning = true;
    _isFinished = false;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _isRunning = false;
        _isFinished = true;
        timer.cancel();
        notifyListeners();
        onTimerComplete?.call();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void resumeTimer() {
    if (_remainingSeconds > 0 && !_isRunning) {
      _isRunning = true;
      notifyListeners();

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          notifyListeners();
        } else {
          _isRunning = false;
          _isFinished = true;
          timer.cancel();
          notifyListeners();
          onTimerComplete?.call();
        }
      });
    }
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;
    _isRunning = false;
    _isFinished = false;
    notifyListeners();
  }

  void addTime(int seconds) {
    _remainingSeconds += seconds;
    _totalSeconds += seconds;
    notifyListeners();
  }

  void setTime(int seconds) {
    _remainingSeconds = seconds;
    _totalSeconds = seconds;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
