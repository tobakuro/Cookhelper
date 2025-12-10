import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../gemini/gemini_text_service.dart';

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key});

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class RecipeLink {
  final String name;
  final String url;
  final String site;

  RecipeLink({
    required this.name,
    required this.url,
    required this.site,
  });
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  final GeminiTextService _geminiService = GeminiTextService();
  final TextEditingController _searchController = TextEditingController();
  List<RecipeLink> _recipeLinks = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchRecipe() async {
    if (_searchController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('料理名またはジャンルを入力してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _recipeLinks = [];
    });

    try {
      final searchQuery = _searchController.text.trim();

      final prompt = '''
以下の料理名またはジャンルに基づき、Web上の信頼できるレシピサイト（クックパッド、楽天レシピ、Delish Kitchenなど）のレシピを5つ提案してください。

検索キーワード: $searchQuery

回答は以下の形式で記載してください:

【レシピ1】
料理名: （料理名）
サイト名: （サイト名）
URL: （レシピページのURL）

【レシピ2】
料理名: （料理名）
サイト名: （サイト名）
URL: （レシピページのURL）

以下同様に5つまで

注意:
- URLは必ず実在する日本のレシピサイトのものを提案してください
- クックパッド、楽天レシピ、Delish Kitchen、白ごはん.com、みんなのきょうの料理などから選んでください
''';

      final response = await _geminiService.generateContent(prompt);

      // レシピリンクを解析
      final recipeLinks = _parseRecipeLinks(response);

      setState(() {
        _recipeLinks = recipeLinks;
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

  List<RecipeLink> _parseRecipeLinks(String response) {
    final List<RecipeLink> recipeLinks = [];
    final lines = response.split('\n');

    String? currentName;
    String? currentSite;
    String? currentUrl;

    for (var line in lines) {
      final trimmedLine = line.trim();

      // 料理名の抽出
      if (trimmedLine.startsWith('料理名:') || trimmedLine.startsWith('料理名：')) {
        currentName = trimmedLine.replaceFirst(RegExp(r'^料理名[：:]\s*'), '').trim();
      }

      // サイト名の抽出
      if (trimmedLine.startsWith('サイト名:') || trimmedLine.startsWith('サイト名：')) {
        currentSite = trimmedLine.replaceFirst(RegExp(r'^サイト名[：:]\s*'), '').trim();
      }

      // URLの抽出
      if (trimmedLine.startsWith('URL:') || trimmedLine.startsWith('URL：')) {
        currentUrl = trimmedLine.replaceFirst(RegExp(r'^URL[：:]\s*'), '').trim();

        // 3つの情報が揃ったらRecipeLinkを作成
        if (currentName != null && currentSite != null && currentUrl != null) {
          recipeLinks.add(RecipeLink(
            name: currentName,
            url: currentUrl,
            site: currentSite,
          ));

          // リセット
          currentName = null;
          currentSite = null;
          currentUrl = null;
        }
      }
    }

    return recipeLinks;
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URLを開けませんでした')),
        );
      }
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
            // 検索フィールド
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: '料理名・ジャンル',
                hintText: '例: カレー、パスタ、和食、スイーツ',
                border: OutlineInputBorder(),
                helperText: '料理名またはジャンル（米、麺、パン、イタリア料理など）を入力',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _searchRecipe(),
            ),
            const SizedBox(height: 16),

            // 検索ボタン
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _searchRecipe,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('レシピを検索'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            // レシピ一覧または状態表示
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recipeLinks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '料理名やジャンルで検索してください',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '例: カレー、イタリア料理、和食、スイーツ',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _recipeLinks.length,
                          itemBuilder: (context, index) {
                            final recipeLink = _recipeLinks[index];
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () => _launchUrl(recipeLink.url),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.link,
                                          size: 32,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              recipeLink.name,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.public,
                                                  size: 16,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  recipeLink.site,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.open_in_new,
                                        color: Colors.blue.shade700,
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
