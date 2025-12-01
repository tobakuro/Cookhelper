import 'package:flutter/material.dart';
import '../gemini/gemini_text_service.dart';
import 'cooking_screen.dart';

class RecipeGenerateScreen extends StatefulWidget {
  const RecipeGenerateScreen({super.key});

  @override
  State<RecipeGenerateScreen> createState() => _RecipeGenerateScreenState();
}

class _RecipeGenerateScreenState extends State<RecipeGenerateScreen> {
  final GeminiTextService _geminiService = GeminiTextService();
  final TextEditingController _ingredientsController = TextEditingController();
  String _recipe = '';
  String _generatedRecipeName = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _ingredientsController.dispose();
    super.dispose();
  }

  Future<void> _generateRecipe() async {
    if (_ingredientsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('材料を入力してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _recipe = '';
      _generatedRecipeName = '';
    });

    try {
      final prompt = '''
手元にある材料: ${_ingredientsController.text}

あなたは優秀な料理研究家です。
上記の材料を使って作れる料理のレシピを1つ提案してください。
食材は必ず指定された物のみを扱うようにしてください。調味料は自由に使用してかまいません。
以下の形式で詳しく教えてください：

【料理名】
【調理時間】
【材料】（1人分）
- 使用する材料とその分量をリスト形式で記載

【作り方】
手順は必ず「ステップ1:」「ステップ2:」という形式で番号を振ってください。
各ステップは1つの具体的な動作のみを含めてください。

例：
ステップ1: 玉ねぎを薄切りにします
ステップ2: フライパンに油を引いて中火で熱します
ステップ3: 玉ねぎを入れて透明になるまで炒めます

このように、細かく分けて10〜15ステップ程度で記載してください。

【ポイント】
- コツや注意点を記載

日本語で、わかりやすく、料理初心者でも作れるように詳しく説明してください。
できるだけ手元にある材料を活用したレシピを提案してください。
''';

      final response = await _geminiService.generateContent(prompt);

      // 料理名を抽出（簡易的な実装）
      String recipeName = '生成されたレシピ';
      final lines = response.split('\n');
      for (var line in lines) {
        if (line.contains('【料理名】')) {
          final nextLineIndex = lines.indexOf(line) + 1;
          if (nextLineIndex < lines.length) {
            recipeName = lines[nextLineIndex].trim();
            break;
          }
        }
      }

      setState(() {
        _recipe = response;
        _generatedRecipeName = recipeName;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _recipe = 'エラーが発生しました: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レシピ生成'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ingredientsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '手元の材料',
                hintText: '例: 鶏肉、玉ねぎ、にんじん、じゃがいも',
                border: OutlineInputBorder(),
                helperText: '手元にある材料をカンマ区切りで入力してください',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generateRecipe,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('レシピを生成'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            if (_recipe.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '生成されたレシピ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CookingScreen(
                            recipeContent: _recipe,
                            recipeName: _generatedRecipeName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('調理モード'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _recipe.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '材料を入力してレシピを生成してください',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          _recipe,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
