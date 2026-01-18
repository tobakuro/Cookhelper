import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/cooking_step.dart';
import '../services/timer_service.dart';
import '../services/gemini_voice_service.dart';

class CookingScreen extends StatefulWidget {
  final String recipeName;
  final String recipeContent;

  const CookingScreen({
    super.key,
    required this.recipeName,
    required this.recipeContent,
  });

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  // ページ状態: 0=プレビュー, 1=ステップ, 2=完了
  int _currentPage = 0;

  // サービス
  final FlutterTts _flutterTts = FlutterTts();
  final TimerService _timerService = TimerService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GeminiVoiceService _voiceService = GeminiVoiceService();

  // UI状態
  bool _isSpeaking = false;
  bool _isFavorite = false;
  int _rating = 0;

  // レシピデータ
  List<CookingStep> _steps = [];
  List<String> _ingredients = [];
  List<String> _tools = [];
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _parseRecipe();
    _setupTimerCallback();
    _setupVoiceCommands();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _timerService.dispose();
    _audioPlayer.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  // ========== 初期化 ==========

  void _setupVoiceCommands() {
    _voiceService.onCommandReceived = (command, {int? value}) {
      if (!mounted) return;

      switch (command) {
        case VoiceCommand.nextStep:
          _nextStep();
        case VoiceCommand.prevStep:
          _previousStep();
        case VoiceCommand.startTimer:
          _startCurrentTimer();
        case VoiceCommand.stopTimer:
          _timerService.stopTimer();
        case VoiceCommand.pauseTimer:
          _timerService.pauseTimer();
        case VoiceCommand.resumeTimer:
          _timerService.resumeTimer();
        case VoiceCommand.addTimerTime:
          _adjustTimerTime(value ?? 60);
        case VoiceCommand.subtractTimerTime:
          _adjustTimerTime(-(value ?? 60));
        case VoiceCommand.repeatStep:
          _speakCurrentStep();
      }
    };
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage('ja-JP');
      await _flutterTts.setSpeechRate(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });

      _flutterTts.setErrorHandler((msg) {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (e) {
      debugPrint('TTS初期化エラー: $e');
    }
  }

  void _setupTimerCallback() {
    _timerService.onTimerComplete = () async {
      if (!mounted) return;

      try {
        await _audioPlayer.play(AssetSource('alarm.mp3'));
      } catch (e) {
        debugPrint('アラーム再生エラー: $e');
      }

      if (!mounted) return;
      _flutterTts.speak('タイマーが終了しました');

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.alarm, color: Colors.orange, size: 32),
                SizedBox(width: 8),
                Text('タイマー終了'),
              ],
            ),
            content: const Text('タイマーが終了しました！', style: TextStyle(fontSize: 18)),
            actions: [
              ElevatedButton(
                onPressed: () {
                  _audioPlayer.stop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    };
  }

  void _parseRecipe() {
    final lines = widget.recipeContent.split('\n');
    final List<CookingStep> steps = [];
    final List<String> ingredients = [];
    final List<String> tools = [];
    bool inIngredients = false;

    for (var line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.contains('【材料】')) {
        inIngredients = true;
        continue;
      }

      if (inIngredients) {
        if (trimmedLine.startsWith('【')) {
          inIngredients = false;
        } else if (trimmedLine.startsWith('-') || trimmedLine.startsWith('・')) {
          ingredients.add(trimmedLine.replaceFirst(RegExp(r'^[-・]\s*'), ''));
        }
      }

      if (trimmedLine.startsWith('ステップ')) {
        int? timerSeconds;
        String description = trimmedLine;

        final timerPattern = RegExp(r'\[タイマー:\s*(\d+)(分|秒)\]');
        final match = timerPattern.firstMatch(trimmedLine);

        if (match != null) {
          final value = int.parse(match.group(1)!);
          final unit = match.group(2)!;
          timerSeconds = unit == '分' ? value * 60 : value;
          description = trimmedLine.replaceFirst(timerPattern, '').trim();
        }

        steps.add(CookingStep(description: description, timerSeconds: timerSeconds));

        // 器具を推測
        for (var tool in ['フライパン', '鍋', 'ボウル', 'まな板', '包丁']) {
          if (trimmedLine.contains(tool) && !tools.contains(tool)) {
            tools.add(tool);
          }
        }
      }
    }

    setState(() {
      _steps = steps;
      _ingredients = ingredients.isEmpty ? ['材料情報なし'] : ingredients;
      _tools = tools.isEmpty ? ['包丁', 'まな板', 'ボウル'] : tools;
      _currentStepIndex = 0;
    });
  }

  // ========== アクション ==========

  Future<void> _speakCurrentStep() async {
    if (_steps.isEmpty) return;

    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await _flutterTts.speak(_steps[_currentStepIndex].description);
    }
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _timerService.stopTimer();
      setState(() {
        _currentStepIndex++;
        _isSpeaking = false;
      });
      _flutterTts.stop();
      Future.delayed(const Duration(milliseconds: 300), _speakCurrentStep);
    } else {
      // 完了ページへ
      _voiceService.stopListening();
      _timerService.stopTimer();
      setState(() {
        _currentPage = 2;
        _isSpeaking = false;
      });
      _flutterTts.stop();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      _timerService.stopTimer();
      setState(() {
        _currentStepIndex--;
        _isSpeaking = false;
      });
      _flutterTts.stop();
      Future.delayed(const Duration(milliseconds: 300), _speakCurrentStep);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最初のステップです')),
      );
    }
  }

  void _startCurrentTimer() {
    final currentStep = _steps[_currentStepIndex];
    if (currentStep.hasTimer) {
      _timerService.startTimer(currentStep.timerSeconds!);
    }
  }

  void _adjustTimerTime(int seconds) {
    final currentStep = _steps[_currentStepIndex];
    if (currentStep.timerSeconds != null) {
      final newTime = currentStep.timerSeconds! + seconds;
      if (newTime > 0) {
        setState(() {
          _steps[_currentStepIndex] = currentStep.copyWith(timerSeconds: newTime);
        });
      }
    }
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? 'お気に入りに追加しました' : 'お気に入りから削除しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareRecipe() {
    Share.share('${widget.recipeName}\n\n${widget.recipeContent}\n\nCookHelperで作成');
  }

  void _startCooking() {
    setState(() => _currentPage = 1);
    _voiceService.startListening();
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeName, style: const TextStyle(fontSize: 18)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: _currentPage == 1
            ? [
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : null,
                  ),
                  onPressed: _toggleFavorite,
                ),
              ]
            : null,
      ),
      body: switch (_currentPage) {
        0 => _buildPreviewPage(),
        1 => _buildStepPage(),
        _ => _buildCompletionPage(),
      },
    );
  }

  Widget _buildPreviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              widget.recipeName,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          _buildSection(title: '必要な材料', icon: Icons.shopping_basket, items: _ingredients, color: Colors.orange),
          const SizedBox(height: 24),
          _buildSection(title: '必要な器具', icon: Icons.kitchen, items: _tools, color: Colors.blue),
          const SizedBox(height: 24),
          _buildSection(
            title: '調理工程',
            icon: Icons.list_alt,
            items: _steps.map((s) => s.description).toList(),
            color: Colors.green,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startCooking,
              icon: const Icon(Icons.play_arrow, size: 32),
              label: const Text('調理を開始', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key + 1}. ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 16))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStepPage() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 音声認識ステータス
                ListenableBuilder(
                  listenable: _voiceService,
                  builder: (context, _) => _buildVoiceStatusCard(),
                ),
                const SizedBox(height: 16),

                // ステップカウンター
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'ステップ ${_currentStepIndex + 1} / ${_steps.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),

                // ステップ内容
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                  ),
                  child: Text(
                    _steps[_currentStepIndex].description,
                    style: const TextStyle(fontSize: 20, height: 1.8, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

                // タイマーUI
                if (_steps[_currentStepIndex].hasTimer) _buildTimerWidget(),
              ],
            ),
          ),
        ),

        // 操作ボタン
        _buildControlButtons(),
      ],
    );
  }

  Widget _buildVoiceStatusCard() {
    final isListening = _voiceService.isListening;
    final lastCommand = _voiceService.lastCommand;

    return Card(
      color: isListening ? Colors.green.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              isListening ? Icons.mic : Icons.mic_off,
              color: isListening ? Colors.green.shade700 : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isListening ? '音声認識中' : '音声認識停止中',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isListening ? Colors.green.shade900 : Colors.grey.shade700,
                    ),
                  ),
                  if (lastCommand.isNotEmpty)
                    Text(
                      '最後のコマンド: $lastCommand',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
            // 音声認識ON/OFFボタン
            IconButton(
              icon: Icon(isListening ? Icons.stop : Icons.play_arrow),
              onPressed: isListening ? _voiceService.stopListening : _voiceService.startListening,
              color: isListening ? Colors.red : Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerWidget() {
    final currentStep = _steps[_currentStepIndex];
    final timerSeconds = currentStep.timerSeconds!;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ListenableBuilder(
        listenable: _timerService,
        builder: (context, _) {
          final isFinished = _timerService.isFinished;
          final isRunning = _timerService.isRunning;
          final color = isFinished ? Colors.green : Colors.orange;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.shade300, width: 2),
            ),
            child: Column(
              children: [
                // タイトル
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isFinished ? Icons.check_circle : Icons.timer, color: color.shade700, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      isFinished ? '完了!' : 'タイマー',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 円形プログレス
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isRunning || isFinished)
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: isFinished ? 1.0 : _timerService.progress,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(color.shade600),
                          ),
                        ),
                      Text(
                        _timerService.totalSeconds > 0 ? _timerService.displayTime : _formatTime(timerSeconds),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 時間調整ボタン（未開始時のみ）
                if (!isRunning && !isFinished) ...[
                  const Text('時間調整', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuickTimeButton('-1分', -60),
                      const SizedBox(width: 8),
                      _buildQuickTimeButton('-10秒', -10),
                      const SizedBox(width: 8),
                      _buildQuickTimeButton('+10秒', 10),
                      const SizedBox(width: 8),
                      _buildQuickTimeButton('+1分', 60),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // タイマー操作ボタン
                _buildTimerButtons(isRunning, isFinished, timerSeconds),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimerButtons(bool isRunning, bool isFinished, int timerSeconds) {
    if (isFinished) {
      return ElevatedButton.icon(
        onPressed: _timerService.stopTimer,
        icon: const Icon(Icons.refresh),
        label: const Text('リセット'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        ),
      );
    }

    if (isRunning) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _timerService.pauseTimer,
            icon: const Icon(Icons.pause),
            label: const Text('一時停止'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _timerService.stopTimer,
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    // 停止中（一時停止含む）
    if (_timerService.totalSeconds > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _timerService.resumeTimer,
            icon: const Icon(Icons.play_arrow),
            label: const Text('再開'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _timerService.stopTimer,
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    // 未開始
    return ElevatedButton.icon(
      onPressed: () => _timerService.startTimer(timerSeconds),
      icon: const Icon(Icons.play_arrow),
      label: const Text('開始'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildQuickTimeButton(String label, int seconds) {
    return OutlinedButton(
      onPressed: () => _adjustTimerTime(seconds),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: Colors.orange.shade600),
      ),
      child: Text(label, style: TextStyle(color: Colors.orange.shade700, fontSize: 12)),
    );
  }

  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _currentStepIndex > 0 ? _previousStep : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('戻る'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
          ),
          ElevatedButton.icon(
            onPressed: _speakCurrentStep,
            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up, size: 28),
            label: Text(_isSpeaking ? '停止' : '読み上げ'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: _isSpeaking ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _nextStep,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('次へ'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionPage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 100, color: Colors.green),
            const SizedBox(height: 24),
            const Text('調理完了！', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(widget.recipeName, style: const TextStyle(fontSize: 24), textAlign: TextAlign.center),
            const SizedBox(height: 48),

            // お気に入り
            Card(
              child: ListTile(
                leading: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : null,
                  size: 32,
                ),
                title: const Text('お気に入りに追加', style: TextStyle(fontSize: 18)),
                trailing: Switch(value: _isFavorite, onChanged: (_) => _toggleFavorite()),
                onTap: _toggleFavorite,
              ),
            ),
            const SizedBox(height: 16),

            // 共有
            Card(
              child: ListTile(
                leading: const Icon(Icons.share, size: 32),
                title: const Text('レシピを共有', style: TextStyle(fontSize: 18)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _shareRecipe,
              ),
            ),
            const SizedBox(height: 16),

            // 評価
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('レシピを評価', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) => IconButton(
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 40,
                          ),
                          onPressed: () => setState(() => _rating = index + 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // ホームに戻る
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home),
              label: const Text('ホームに戻る'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
