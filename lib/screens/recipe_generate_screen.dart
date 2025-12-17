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
  final String fullContent;

  Recipe({required this.name, required this.fullContent});
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('材料を入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
      _recipes = [];
    });

    try {
      final prompt =
          '''
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

7.各ステップで、調味料などを入れる際は、それが既出のものであっても必ず分量を記載してください

8.入力された食材をすべて使用する必要はありません

以下の形式で提案してください：



===レシピ1===

【料理名】

料理名を記載



【調理時間】

調理時間を記載



【材料】（1人分）

使用する材料とその分量をリスト形式で記載



【作り方】

手順は必ず「ステップ1:」「ステップ2:」という形式で番号を振ってください。

各ステップは1つの具体的な動作のみを含めてください。



例：

ステップ1: 鶏モモ肉100gを4cm角に切ります

ステップ2: セロリ30gを薄切りにします。葉も刻んでおきましょう

ステップ3: フライパンに油を大さじ1杯(20g)引いて中火で熱します

ステップ4: 4cm角に切った鶏肉を加えて、表面に焼き色がつくまで3分ほど炒めます

【ポイント】

コツや注意点を記載



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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
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

    // 各ブロックから料理名を抽出
    for (var block in recipeBlocks) {
      String recipeName = '生成されたレシピ';
      final blockLines = block.split('\n');

      for (int i = 0; i < blockLines.length; i++) {
        if (blockLines[i].contains('【料理名】') && i + 1 < blockLines.length) {
          recipeName = blockLines[i + 1].trim();
          break;
        }
      }

      recipes.add(Recipe(name: recipeName, fullContent: block));
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.restaurant,
                                      size: 32,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          recipe.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'レシピ ${index + 1}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
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
