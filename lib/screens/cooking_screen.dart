import 'package:flutter/material.dart';

// エラーの原因になる import などをすべて削除しました
class CookingScreen extends StatelessWidget {
  const CookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cooking Assistant')),
      body: const Center(
        child: Text('ここに料理の指示が表示される予定です'),
import 'package:flutter_tts/flutter_tts.dart';

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
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isFavorite = false;

  List<String> _steps = [];
  int _currentStepIndex = 0;
  String _header = '';
  String _footer = '';

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _parseRecipe();
  }

  void _parseRecipe() {
    final lines = widget.recipeContent.split('\n');
    final List<String> steps = [];
    final StringBuffer headerBuffer = StringBuffer();
    final StringBuffer footerBuffer = StringBuffer();
    bool inSteps = false;
    bool afterSteps = false;

    for (var line in lines) {
      final trimmedLine = line.trim();

      // 「ステップ」で始まる行を検出
      if (trimmedLine.startsWith('ステップ')) {
        inSteps = true;
        steps.add(trimmedLine);
      } else if (inSteps && trimmedLine.isEmpty) {
        // ステップセクションの終わり
        afterSteps = true;
        inSteps = false;
      } else if (!inSteps && !afterSteps) {
        // ヘッダー部分（材料、料理名など）
        headerBuffer.writeln(line);
      } else if (afterSteps) {
        // フッター部分（ポイントなど）
        footerBuffer.writeln(line);
      }
    }

    setState(() {
      _steps = steps;
      _header = headerBuffer.toString().trim();
      _footer = footerBuffer.toString().trim();
      _currentStepIndex = 0;
    });
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('ja-JP');
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(3.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakCurrentStep() async {
    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ステップが見つかりません')),
      );
      return;
    }

    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
    } else {
      setState(() {
        _isSpeaking = true;
      });
      await _flutterTts.speak(_steps[_currentStepIndex]);
    }
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _isSpeaking = false;
      });
      _flutterTts.stop();
      // 自動的に次のステップを読み上げ
      Future.delayed(const Duration(milliseconds: 300), () {
        _speakCurrentStep();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最後のステップです')),
      );
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
        _isSpeaking = false;
      });
      _flutterTts.stop();
      // 自動的に前のステップを読み上げ
      Future.delayed(const Duration(milliseconds: 300), () {
        _speakCurrentStep();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最初のステップです')),
      );
    }
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFavorite ? 'お気に入りに追加しました' : 'お気に入りから削除しました',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipeName,
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
          ),
        ],
      ),
      body: Column(
        children: [
          // ヘッダー情報（材料など）
          if (_header.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.recipeName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 現在のステップ表示
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ステップカウンター
                  if (_steps.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ステップ ${_currentStepIndex + 1} / ${_steps.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // 現在のステップ内容
                  if (_steps.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        _steps[_currentStepIndex],
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.8,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  if (_steps.isEmpty)
                    const Center(
                      child: Text(
                        'ステップが見つかりませんでした',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 操作ボタン
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ナビゲーションボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 戻るボタン
                    ElevatedButton.icon(
                      onPressed: _currentStepIndex > 0 ? _previousStep : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('戻る'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),

                    // 再生/停止ボタン
                    ElevatedButton.icon(
                      onPressed: _steps.isNotEmpty ? _speakCurrentStep : null,
                      icon: Icon(
                        _isSpeaking ? Icons.stop : Icons.volume_up,
                        size: 28,
                      ),
                      label: Text(
                        _isSpeaking ? '停止' : '読み上げ',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        backgroundColor: _isSpeaking ? Colors.red : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),

                    // 次へボタン
                    ElevatedButton.icon(
                      onPressed: _currentStepIndex < _steps.length - 1
                          ? _nextStep
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('次へ'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}