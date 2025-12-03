import 'package:flutter/material.dart';
import '../gemini/gemini_text_service.dart';
import 'cooking_screen.dart';

class RecipeGenerateScreen extends StatefulWidget {
  const RecipeGenerateScreen({super.key});

  @override
  State<RecipeGenerateScreen> createState() => _RecipeGenerateScreenState();
}

class Recipe {
  final String name;
  final String cookingTime;
  final List<String> ingredients;
  final String fullContent;

  Recipe({
    required this.name,
    required this.cookingTime,
    required this.ingredients,
    required this.fullContent,
  });
}

class _RecipeGenerateScreenState extends State<RecipeGenerateScreen> {
  final GeminiTextService _geminiService = GeminiTextService();
  final TextEditingController _ingredientsController = TextEditingController();
  List<Recipe> _recipes = [];
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
      _recipes = [];
    });

    try {
      final prompt = '''
手元にある材料: ${_ingredientsController.text}

あなたは様々な料理に詳しいプロの料理研究家です。
入力された冷蔵庫の中身およびユーザの料理の好みに基づき、以下のルールに従って３つの料理を提案して下さい。
ルール
1.提案する料理は必ず入力された食材のみを使用し、基本的な調味料（砂糖、醤油、味噌、塩、酢、サラダ油、etc）は常備されているものとして無視してかまいません。
2.調理時間は最長でも60分以内のものを提案してください。
3.使いたい材料がある場合は優先して使ってください
4.回答はユーザーが入力した言語に合わせてください
5.必ず3つのレシピを「===レシピ1===」「===レシピ2===」「===レシピ3===」で区切ってください
6.各レシピは10〜15ステップ程度に細かく分けてください
7.調味料などを入れる際は必ず分量を記載してください
以下の形式で提案してください：

===レシピ1===
【料理名】
料理名を記載

【調理時間】
調理時間を記載

【材料】（1人分）
- 使用する材料とその分量をリスト形式で記載

【作り方】
手順は必ず「ステップ1:」「ステップ2:」という形式で番号を振ってください。
各ステップは1つの具体的な動作のみを含めてください。

例：
ステップ1: 玉ねぎを薄切りにします
ステップ2: フライパンに油を大さじ1杯引いて中火で熱します
ステップ3: 玉ねぎを入れて透明になるまで炒めます

【ポイント】
- コツや注意点を記載

===レシピ2===
（同じ形式で2つ目のレシピ）

===レシピ3===
（同じ形式で3つ目のレシピ）
''';

      final response = await _geminiService.generateContent(prompt);

      // レシピを解析
      final recipes = _parseRecipes(response);

      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  List<Recipe> _parseRecipes(String response) {
    final List<Recipe> recipes = [];

    // ===レシピ1===, ===レシピ2===, ===レシピ3=== で分割
    final recipeBlocks = <String>[];
    final lines = response.split('\n');
    StringBuffer currentBlock = StringBuffer();
    bool inRecipe = false;

    for (var line in lines) {
      if (line.contains('===レシピ')) {
        if (inRecipe && currentBlock.isNotEmpty) {
          recipeBlocks.add(currentBlock.toString());
          currentBlock.clear();
        }
        inRecipe = true;
      } else if (inRecipe) {
        currentBlock.writeln(line);
      }
    }

    // 最後のブロックを追加
    if (currentBlock.isNotEmpty) {
      recipeBlocks.add(currentBlock.toString());
    }

    // 各ブロックから料理名、調理時間、材料を抽出
    for (var block in recipeBlocks) {
      String recipeName = '生成されたレシピ';
      String cookingTime = '不明';
      List<String> ingredients = [];
      final blockLines = block.split('\n');

      bool inIngredients = false;

      for (int i = 0; i < blockLines.length; i++) {
        final line = blockLines[i].trim();

        // 料理名の抽出
        if (line.contains('【料理名】')) {
          // 同じ行に料理名がある場合: 【料理名】親子丼
          final sameLine = line.replaceFirst('【料理名】', '').trim();
          if (sameLine.isNotEmpty) {
            recipeName = sameLine;
          } else if (i + 1 < blockLines.length) {
            // 次の行に料理名がある場合
            recipeName = blockLines[i + 1].trim();
          }
        }

        // 調理時間の抽出
        if (line.contains('【調理時間】')) {
          // 同じ行に調理時間がある場合: 【調理時間】30分
          final sameLine = line.replaceFirst('【調理時間】', '').trim();
          if (sameLine.isNotEmpty) {
            cookingTime = sameLine;
          } else if (i + 1 < blockLines.length) {
            // 次の行に調理時間がある場合
            cookingTime = blockLines[i + 1].trim();
          }
        }

        // 材料の抽出
        if (line.contains('【材料】')) {
          inIngredients = true;
          continue;
        }

        if (inIngredients) {
          // 次のセクション（【作り方】など）が始まったら終了
          if (line.startsWith('【') && line.endsWith('】')) {
            inIngredients = false;
          } else if (line.startsWith('-') || line.startsWith('・')) {
            // 材料行を追加（先頭の記号を除去）
            final ingredient = line.replaceFirst(RegExp(r'^[-・]\s*'), '').trim();
            if (ingredient.isNotEmpty) {
              ingredients.add(ingredient);
            }
          }
        }
      }

      recipes.add(Recipe(
        name: recipeName,
        cookingTime: cookingTime,
        ingredients: ingredients,
        fullContent: block,
      ));
    }

    return recipes;
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

            // レシピ選択ボタン
            if (_recipes.isNotEmpty) ...[
              const Text(
                '作りたいレシピを選択してください',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recipes.isEmpty
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
                      : ListView.builder(
                          itemCount: _recipes.length,
                          itemBuilder: (context, index) {
                            final recipe = _recipes[index];
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CookingScreen(
                                        recipeContent: recipe.fullContent,
                                        recipeName: recipe.name,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.restaurant,
                                          size: 32,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              recipe.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  recipe.cookingTime,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: [
                                                ...recipe.ingredients.take(3).map((ingredient) {
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.shade50,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: Colors.orange.shade200,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      ingredient.split(' ').first.split('　').first,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.orange.shade900,
                                                      ),
                                                    ),
                                                  );
                                                }),
                                                if (recipe.ingredients.length > 3)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    child: Text(
                                                      '他${recipe.ingredients.length - 3}品',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey.shade600,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
