import 'package:flutter/material.dart';
import '../gemini/gemini_text_service.dart';
import 'recipe_detail_screen.dart';

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key});

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  final GeminiTextService _geminiService = GeminiTextService();
  final TextEditingController _searchController = TextEditingController();
  String _recipe = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchRecipe() async {
    if (_searchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('料理名を入力してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _recipe = '';
    });

    try {
      final prompt = '''
料理名: ${_searchController.text}

上記の料理のレシピを以下の形式で詳しく教えてください：

【料理名】
【調理時間】
【材料】（2人分）
【作り方】
1.
2.
3.
（必要な手順を全て記載）

【ポイント】
- コツや注意点を記載

日本語で、わかりやすく、料理初心者でも作れるように詳しく説明してください。
''';

      final response = await _geminiService.generateContent(prompt);

      setState(() {
        _recipe = response;
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
        title: const Text('レシピ検索'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: '料理名',
                      hintText: '例: カレーライス、親子丼',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _searchRecipe(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _searchRecipe,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_recipe.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'レシピ',
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
                          builder: (context) => RecipeDetailScreen(
                            recipeContent: _recipe,
                            recipeName: _searchController.text,
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
                              Icons.restaurant,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '料理名を入力して検索してください',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
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
