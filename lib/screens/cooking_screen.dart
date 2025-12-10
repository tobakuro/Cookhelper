import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:share_plus/share_plus.dart';

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
  int _currentPage = 0; // 0: プレビュー, 1: ステップ, 2: 完了

  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();

  bool _isSpeaking = false;
  bool _isListening = false;
  bool _isFavorite = false;
  String _recognizedText = '';
  int _rating = 0;

  List<String> _steps = [];
  List<String> _ingredients = [];
  List<String> _tools = [];
  int _currentStepIndex = 0;
  String _header = '';
  String _footer = '';

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeSpeechRecognition();
    _parseRecipe();
  }

  Future<void> _initializeSpeechRecognition() async {
    await _speechToText.initialize();
  }

  void _parseRecipe() {
    final lines = widget.recipeContent.split('\n');
    final List<String> steps = [];
    final List<String> ingredients = [];
    final List<String> tools = [];
    final StringBuffer headerBuffer = StringBuffer();
    final StringBuffer footerBuffer = StringBuffer();

    bool inSteps = false;
    bool afterSteps = false;
    bool inIngredients = false;

    for (var line in lines) {
      final trimmedLine = line.trim();

      // 材料セクション
      if (trimmedLine.contains('【材料】')) {
        inIngredients = true;
        continue;
      }

      // 材料の抽出
      if (inIngredients) {
        if (trimmedLine.startsWith('【')) {
          inIngredients = false;
        } else if (trimmedLine.startsWith('-') || trimmedLine.startsWith('・')) {
          ingredients.add(trimmedLine.replaceFirst(RegExp(r'^[-・]\s*'), ''));
        }
      }

      // ステップの抽出
      if (trimmedLine.startsWith('ステップ')) {
        inSteps = true;
        steps.add(trimmedLine);

        // ステップから器具を推測
        if (trimmedLine.contains('フライパン') && !tools.contains('フライパン')) {
          tools.add('フライパン');
        }
        if (trimmedLine.contains('鍋') && !tools.contains('鍋')) {
          tools.add('鍋');
        }
        if (trimmedLine.contains('ボウル') && !tools.contains('ボウル')) {
          tools.add('ボウル');
        }
        if (trimmedLine.contains('まな板') && !tools.contains('まな板')) {
          tools.add('まな板');
        }
        if (trimmedLine.contains('包丁') && !tools.contains('包丁')) {
          tools.add('包丁');
        }
      } else if (inSteps && trimmedLine.isEmpty) {
        afterSteps = true;
        inSteps = false;
      } else if (!inSteps && !afterSteps) {
        headerBuffer.writeln(line);
      } else if (afterSteps) {
        footerBuffer.writeln(line);
      }
    }

    setState(() {
      _steps = steps;
      _ingredients = ingredients.isEmpty ? ['材料情報なし'] : ingredients;
      _tools = tools.isEmpty ? ['包丁', 'まな板', 'ボウル'] : tools;
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
      // 全ステップ完了 - 完了ページへ
      setState(() {
        _currentPage = 2;
        _isSpeaking = false;
      });
      _flutterTts.stop();
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

  Future<void> _startListening() async {
    if (!_isListening) {
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });

      await _speechToText.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });
          if (result.finalResult) {
            _processVoiceCommand(_recognizedText);
            setState(() {
              _isListening = false;
            });
          }
        },
        localeId: 'ja_JP',
      );
    }
  }

  void _processVoiceCommand(String command) {
    final lowerCommand = command.toLowerCase();
    if (lowerCommand.contains('次') || lowerCommand.contains('つぎ')) {
      _nextStep();
    } else if (lowerCommand.contains('戻る') || lowerCommand.contains('もどる')) {
      _previousStep();
    } else if (lowerCommand.contains('もう一度') || lowerCommand.contains('繰り返し')) {
      _speakCurrentStep();
    } else if (lowerCommand.contains('停止') || lowerCommand.contains('止めて')) {
      _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  void _shareRecipe() {
    final shareText = '''
${widget.recipeName}

${widget.recipeContent}

CookHelperで作成
''';
    Share.share(shareText);
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
        actions: _currentPage == 1
            ? [
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : null,
                  ),
                  onPressed: _toggleFavorite,
                  tooltip: _isFavorite ? 'お気に入りから削除' : 'お気に入りに追加',
                ),
              ]
            : null,
      ),
      body: _currentPage == 0
          ? _buildPreviewPage()
          : _currentPage == 1
              ? _buildStepPage()
              : _buildCompletionPage(),
    );
  }

  // プレビューページ
  Widget _buildPreviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 料理名
          Center(
            child: Text(
              widget.recipeName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // 材料セクション
          _buildSection(
            title: '必要な材料',
            icon: Icons.shopping_basket,
            items: _ingredients,
            color: Colors.orange,
          ),
          const SizedBox(height: 24),

          // 器具セクション
          _buildSection(
            title: '必要な器具',
            icon: Icons.kitchen,
            items: _tools,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),

          // 工程一覧セクション
          _buildSection(
            title: '調理工程',
            icon: Icons.list_alt,
            items: _steps,
            color: Colors.green,
          ),
          const SizedBox(height: 32),

          // スタートボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentPage = 1;
                });
              },
              icon: const Icon(Icons.play_arrow, size: 32),
              label: const Text(
                '調理を開始',
                style: TextStyle(fontSize: 20),
              ),
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key + 1}. ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ステップバイステップページ
  Widget _buildStepPage() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // ステップカウンター
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    _steps[_currentStepIndex],
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.8,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
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
              // 音声コマンド表示
              if (_isListening)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _recognizedText.isEmpty ? '聞いています...' : _recognizedText,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentStepIndex > 0 ? _previousStep : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('戻る'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 音声コマンドボタン
              ElevatedButton.icon(
                onPressed: _startListening,
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 28),
                label: Text(_isListening ? '聞いています...' : '音声コマンド'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 完了ページ
  Widget _buildCompletionPage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.celebration,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            const Text(
              '調理完了！',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              widget.recipeName,
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // お気に入りボタン
            Card(
              child: ListTile(
                leading: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : null,
                  size: 32,
                ),
                title: const Text('お気に入りに追加', style: TextStyle(fontSize: 18)),
                trailing: Switch(
                  value: _isFavorite,
                  onChanged: (value) => _toggleFavorite(),
                ),
                onTap: _toggleFavorite,
              ),
            ),
            const SizedBox(height: 16),

            // 共有ボタン
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
                    const Text(
                      'レシピを評価',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 40,
                          ),
                          onPressed: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // ホームに戻るボタン
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
