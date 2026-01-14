import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/cooking_step.dart';
import '../services/timer_service.dart';

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
  bool _speechAvailable = false; // 音声認識が利用可能か
  String _recognizedText = '';
  String _lastError = ''; // エラーメッセージ
  int _rating = 0;
  bool _isOnCookingPage = false; // 調理ページにいるかどうか

  List<CookingStep> _steps = [];
  List<String> _ingredients = [];
  List<String> _tools = [];
  int _currentStepIndex = 0;

  final TimerService _timerService = TimerService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeSpeechRecognition();
    _parseRecipe();
    _setupTimerCallback();
  }

  void _setupTimerCallback() {
    _timerService.onTimerComplete = () async {
      if (!mounted) return;

      // アラーム音を再生
      try {
        await _audioPlayer.play(AssetSource('alarm.mp3'));
      } catch (e) {
        // アラーム音の再生に失敗した場合はログに記録（本番環境ではロギングフレームワークを使用）
        if (mounted) {
          debugPrint('アラーム音の再生に失敗しました: $e');
        }
      }

      if (!mounted) return;

      // 音声で通知
      _flutterTts.speak('タイマーが終了しました');

      // ダイアログで通知
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
            content: const Text(
              'タイマーが終了しました！',
              style: TextStyle(fontSize: 18),
            ),
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

  Future<void> _initializeSpeechRecognition() async {
    try {
      // 音声認識の初期化（Web版ではパーミッション処理をスキップ）
      bool available = await _speechToText.initialize(
        onError: (error) {
          print('🔴 音声認識エラー: ${error.errorMsg}'); // デバッグログ
          if (mounted) {
            setState(() {
              _lastError = '音声認識エラー: ${error.errorMsg}';
              _isListening = false;
            });
          }
        },
        onStatus: (status) {
          print('🔵 音声認識ステータス: $status'); // デバッグログ
          // 調理ページにいる間は常に音声認識を再開
          if (status == 'notListening' && _isOnCookingPage && mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isOnCookingPage && !_isListening && mounted) {
                print('🟢 音声認識を再開します'); // デバッグログ
                _startListening();
              }
            });
          }
        },
      );

      print('🟡 音声認識初期化完了: available=$available'); // デバッグログ
      if (mounted) {
        setState(() {
          _speechAvailable = available;
          if (!available) {
            _lastError = 'この端末では音声認識が利用できません';
          } else {
            _lastError = ''; // 成功したらエラーをクリア
          }
        });
      }
    } catch (e) {
      print('🔴 音声認識初期化失敗: $e'); // デバッグログ
      if (mounted) {
        setState(() {
          _lastError = '音声認識の初期化に失敗しました: $e';
          _speechAvailable = false;
        });
      }
    }
  }

  void _parseRecipe() {
    final lines = widget.recipeContent.split('\n');
    final List<CookingStep> steps = [];
    final List<String> ingredients = [];
    final List<String> tools = [];

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
        // タイマー情報を抽出
        int? timerSeconds;
        String description = trimmedLine;

        // [タイマー: XX分] または [タイマー: XX秒] のパターンを検索
        final timerPattern = RegExp(r'\[タイマー:\s*(\d+)(分|秒)\]');
        final match = timerPattern.firstMatch(trimmedLine);

        if (match != null) {
          final value = int.parse(match.group(1)!);
          final unit = match.group(2)!;

          if (unit == '分') {
            timerSeconds = value * 60;
          } else {
            timerSeconds = value;
          }

          // タイマー情報を除いた説明文を取得
          description = trimmedLine.replaceFirst(timerPattern, '').trim();
        }

        steps.add(CookingStep(
          description: description,
          timerSeconds: timerSeconds,
        ));

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
      }
    }

    setState(() {
      _steps = steps;
      _ingredients = ingredients.isEmpty ? ['材料情報なし'] : ingredients;
      _tools = tools.isEmpty ? ['包丁', 'まな板', 'ボウル'] : tools;
      _currentStepIndex = 0;
    });
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage('ja-JP');
      await _flutterTts.setSpeechRate(1.0);
      await _flutterTts.setVolume(1.0);
      // Web版ではピッチ設定が原因でエラーになる場合があるので調整
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
        }
      });

      _flutterTts.setErrorHandler((msg) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _lastError = '音声読み上げエラー: $msg';
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastError = '音声読み上げの初期化に失敗しました: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _isOnCookingPage = false;
    _flutterTts.stop();
    _speechToText.stop();
    _timerService.dispose();
    _audioPlayer.dispose();
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
      await _flutterTts.speak(_steps[_currentStepIndex].description);
    }
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      // タイマーをリセット
      _timerService.stopTimer();

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
      _isOnCookingPage = false;
      _speechToText.stop();
      _timerService.stopTimer();

      setState(() {
        _currentPage = 2;
        _isSpeaking = false;
        _isListening = false;
      });
      _flutterTts.stop();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      // タイマーをリセット
      _timerService.stopTimer();

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
    print('🎤 _startListening 呼び出し: speechAvailable=$_speechAvailable, isOnCookingPage=$_isOnCookingPage'); // デバッグログ

    if (!_speechAvailable || !_isOnCookingPage) {
      print('⚠️ 音声認識開始条件を満たしていません'); // デバッグログ
      return;
    }

    if (!_isListening) {
      print('✅ 音声認識を開始します'); // デバッグログ
      setState(() {
        _isListening = true;
        _recognizedText = '';
        _lastError = '';
      });

      try {
        // 利用可能なロケールを確認
        final locales = await _speechToText.locales();
        print('📋 利用可能なロケール: ${locales.map((l) => l.localeId).join(", ")}');

        // デフォルトロケール（英語）でテスト - Web版では日本語が動作しない可能性がある
        final useLocale = 'en_US'; // テスト用に英語を使用
        print('🌐 使用するロケール: $useLocale');

        await _speechToText.listen(
          onResult: (result) {
            print('🎙️ 音声認識結果: "${result.recognizedWords}" (final=${result.finalResult}, confidence=${result.confidence})'); // デバッグログ
            if (mounted) {
              setState(() {
                _recognizedText = result.recognizedWords;
              });
              if (result.finalResult && result.recognizedWords.isNotEmpty) {
                // 「ヘルパー」が含まれている場合のみコマンドを処理
                print('📝 最終結果を処理: ${result.recognizedWords}'); // デバッグログ
                _processVoiceCommand(_recognizedText);
              }
            }
          },
          onSoundLevelChange: (level) {
            // 音声レベルをログ出力（デバッグ用）
            print('🔊 音声レベル: $level');
          },
          localeId: useLocale,
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
            listenMode: ListenMode.confirmation,
          ),
          pauseFor: const Duration(seconds: 5),
          listenFor: const Duration(seconds: 60),
        );
        print('🎧 音声認識リスニング開始完了'); // デバッグログ
      } catch (e) {
        print('🔴 音声認識開始エラー: $e'); // デバッグログ
        if (mounted) {
          setState(() {
            _lastError = '音声認識の開始に失敗しました: $e';
            _isListening = false;
          });
        }
      }
    } else {
      print('⚠️ 既に音声認識が実行中です'); // デバッグログ
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _processVoiceCommand(String command) {
    print('🔍 音声コマンド処理開始: "$command"'); // デバッグログ
    final lowerCommand = command.toLowerCase();

    // 「ヘルパー」が含まれているかチェック
    if (!lowerCommand.contains('ヘルパー') &&
        !lowerCommand.contains('へるぱー') &&
        !lowerCommand.contains('helper')) {
      // ヘルパーが含まれていない場合は無視
      print('⏭️ ヘルパーが含まれていないため無視します'); // デバッグログ
      return;
    }

    print('✅ ヘルパーを検出しました。コマンドを解析します'); // デバッグログ

    // 次へのコマンド
    if (lowerCommand.contains('次') ||
        lowerCommand.contains('つぎ') ||
        lowerCommand.contains('進む') ||
        lowerCommand.contains('すすむ') ||
        lowerCommand.contains('進んで') ||
        lowerCommand.contains('次のステップ') ||
        lowerCommand.contains('ネクスト')) {
      print('⏩ 次へコマンドを実行'); // デバッグログ
      _nextStep();
      return;
    }

    // 戻るのコマンド
    if (lowerCommand.contains('戻る') ||
        lowerCommand.contains('もどる') ||
        lowerCommand.contains('前') ||
        lowerCommand.contains('まえ') ||
        lowerCommand.contains('戻して') ||
        lowerCommand.contains('前のステップ') ||
        lowerCommand.contains('バック')) {
      print('⏪ 戻るコマンドを実行'); // デバッグログ
      _previousStep();
      return;
    }

    // 繰り返しのコマンド
    if (lowerCommand.contains('もう一度') ||
        lowerCommand.contains('もう1度') ||
        lowerCommand.contains('繰り返し') ||
        lowerCommand.contains('くりかえし') ||
        lowerCommand.contains('リピート') ||
        lowerCommand.contains('読んで') ||
        lowerCommand.contains('よんで') ||
        lowerCommand.contains('もう一回')) {
      print('🔁 繰り返しコマンドを実行'); // デバッグログ
      _speakCurrentStep();
      return;
    }

    // 停止のコマンド
    if (lowerCommand.contains('停止') ||
        lowerCommand.contains('ていし') ||
        lowerCommand.contains('止めて') ||
        lowerCommand.contains('やめて') ||
        lowerCommand.contains('ストップ') ||
        lowerCommand.contains('黙って')) {
      print('⏹️ 停止コマンドを実行'); // デバッグログ
      _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
      return;
    }

    // ヘルパーは含まれているが、認識できるコマンドがなかった場合
    print('❓ ヘルパーは検出されましたが、有効なコマンドが見つかりません'); // デバッグログ
    if (mounted) {
      setState(() {
        _lastError = 'コマンドを認識できませんでした';
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
            items: _steps.map((step) => step.description).toList(),
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

  // タイマーウィジェット
  Widget _buildTimerWidget() {
    final currentStep = _steps[_currentStepIndex];
    final timerSeconds = currentStep.timerSeconds!;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ListenableBuilder(
        listenable: _timerService,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _timerService.isFinished
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _timerService.isFinished
                    ? Colors.green.shade300
                    : Colors.orange.shade300,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                // タイマーアイコンとタイトル
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _timerService.isFinished
                          ? Icons.check_circle
                          : Icons.timer,
                      color: _timerService.isFinished
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timerService.isFinished ? '完了!' : 'タイマー',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _timerService.isFinished
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // タイマー表示
                Column(
                  children: [
                    // 円形プログレスバー
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_timerService.isRunning || _timerService.isFinished)
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: _timerService.isFinished
                                    ? 1.0
                                    : _timerService.progress,
                                strokeWidth: 8,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _timerService.isFinished
                                      ? Colors.green.shade600
                                      : Colors.orange.shade600,
                                ),
                              ),
                            ),
                          Text(
                            _timerService.totalSeconds > 0
                                ? _timerService.displayTime
                                : _formatTime(timerSeconds),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: _timerService.isFinished
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

                // 時間調整ボタン（タイマー未開始または停止中のみ表示）
                if (!_timerService.isRunning && !_timerService.isFinished)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        const Text(
                          '時間調整',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                      ],
                    ),
                  ),

                // タイマーボタン
                if (!_timerService.isRunning && !_timerService.isFinished)
                  // 開始ボタン
                  ElevatedButton.icon(
                    onPressed: () {
                      _timerService.startTimer(timerSeconds);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('開始'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                  ),
                if (_timerService.isRunning)
                  // 一時停止と停止ボタン（タイマー動作中のみ）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _timerService.pauseTimer();
                        },
                        icon: const Icon(Icons.pause),
                        label: const Text('一時停止'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          _timerService.stopTimer();
                        },
                        icon: const Icon(Icons.stop),
                        label: const Text('停止'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (!_timerService.isRunning &&
                    !_timerService.isFinished &&
                    _timerService.totalSeconds > 0)
                  // 再開と停止ボタン（一時停止中のみ）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _timerService.resumeTimer();
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('再開'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          _timerService.stopTimer();
                        },
                        icon: const Icon(Icons.stop),
                        label: const Text('停止'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_timerService.isFinished)
                  // リセットボタン
                  ElevatedButton.icon(
                    onPressed: () {
                      _timerService.stopTimer();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('リセット'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
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
      onPressed: () {
        final currentStep = _steps[_currentStepIndex];
        final newTime = currentStep.timerSeconds! + seconds;
        if (newTime > 0) {
          setState(() {
            _steps[_currentStepIndex] = currentStep.copyWith(
              timerSeconds: newTime,
            );
          });
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: Colors.orange.shade600),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
      ),
    );
  }

  // ステップバイステップページ
  Widget _buildStepPage() {
    // 調理ページに入ったら音声認識を開始（build外で実行）
    if (!_isOnCookingPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isOnCookingPage && mounted) {
          setState(() {
            _isOnCookingPage = true;
          });
          if (_speechAvailable) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _startListening();
            });
          }
        }
      });
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 音声認識の説明カード
                if (_speechAvailable)
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.mic, color: Colors.blue.shade700, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '音声コマンドが有効です',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '「ヘルパー、次へ」のように、ヘルパーを付けて話しかけてください',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

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
                    _steps[_currentStepIndex].description,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.8,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // タイマーUI
                if (_steps[_currentStepIndex].hasTimer)
                  _buildTimerWidget(),
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
              // エラーメッセージ表示
              if (_lastError.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastError,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _lastError = '';
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

              // 音声コマンド表示
              if (_isListening)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // アニメーション付きマイクアイコン
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: 1.2),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Icon(
                              Icons.mic,
                              color: Colors.orange.shade700,
                              size: 24,
                            ),
                          );
                        },
                        onEnd: () {
                          // アニメーションをループさせるためにsetStateを呼ぶ
                          if (_isListening && mounted) {
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _recognizedText.isEmpty
                              ? '聞いています...'
                              : '「$_recognizedText」',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
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
