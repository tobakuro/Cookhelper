import 'package:flutter/material.dart';
import 'recipe_search_screen.dart';
import 'recipe_generate_screen.dart';
import 'favorites_screen.dart';
import 'cooking_screen.dart';
import 'audio_record_test_screen.dart';
// ★ 1. GoogleLiveAPITestScreen のインポートを追加
import 'google_live_api_test_screen.dart'; 

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CookHelper'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // Scrollableにするため、CenterをListViewに変更することが推奨されますが、
      // 今回は既存の構造に合わせてColumnにメニューを追加します。
      body: Center(
        child: SingleChildScrollView( // ★ 項目が増えたため、スクロール可能にする
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.restaurant_menu,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 16),
              const Text(
                '料理をもっと楽しく!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '食材を検索、音声でレシピを操作',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              
              // --- 既存のメニュー ---
              // レシピ検索
              _buildMenuButton(
                context,
                icon: Icons.search,
                label: 'レシピ検索',
                description: '料理名で検索',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecipeSearchScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // レシピ生成
              _buildMenuButton(
                context,
                icon: Icons.auto_awesome,
                label: 'レシピ生成',
                description: '手持ちからレシピを作成',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecipeGenerateScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 音声操作モード
              _buildMenuButton(
                context,
                icon: Icons.mic,
                label: '音声操作モード',
                description: 'ハンズフリーで操作',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CookingScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // お気に入り
              _buildMenuButton(
                context,
                icon: Icons.favorite,
                label: 'お気に入り',
                description: '保存したレシピ',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoritesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 音声録音テスト
              _buildMenuButton(
                context,
                icon: Icons.mic_external_on,
                label: '音声録音テスト',
                description: 'マイク録音機能のテスト',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AudioRecordTestScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // ★ 2. 新しいメニューボタンの追加
              _buildMenuButton(
                context,
                icon: Icons.cloud_upload, // API接続を示すアイコン
                label: 'Google Live API テスト', 
                description: 'リアルタイム音声認識の接続テスト', 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoogleLiveAPITestScreen(),
                    ),
                  );
                },
              ),
              // --- メニュー終わり ---

            ],
          ),
        ),
      ),
    );
  }

  // _buildMenuButtonメソッドは省略
  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    // ... (元の _buildMenuButton の実装)
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
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
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}