import 'package:flutter/material.dart';
import 'recipe_search_screen.dart';
import 'recipe_generate_screen.dart';
import 'favorites_screen.dart';
import 'cooking_screen.dart';
import 'audio_record_test_screen.dart';
import 'timer_test_screen.dart';

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
      body: Center(
        child: Padding(
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
                '料理をもっと楽しく！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '食材を使って、音声でレシピをナビゲート',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),

              _buildMenuButton(
                context,
                icon: Icons.search,
                label: 'レシピ検索',
                description: '料理名や食材から検索',
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
              _buildMenuButton(
                context,
                icon: Icons.auto_awesome,
                label: 'レシピ生成',
                description: '余った食材からレシピを提案',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const RecipeGenerateScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              _buildMenuButton(
                context,
                icon: Icons.mic,
                label: '音声操作モード',
                description: 'ハンズフリーで料理を進める',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CookingScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              _buildMenuButton(
                context,
                icon: Icons.favorite,
                label: 'お気に入り',
                description: '保存したレシピ一覧',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const FavoritesScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              _buildMenuButton(
                context,
                icon: Icons.mic_external_on,
                label: '音声録音テスト',
                description: 'マイク入力の動作確認',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const AudioRecordTestScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              _buildMenuButton(
                context,
                icon: Icons.timer,
                label: 'タイマーテスト',
                description: 'アラーム・タイマー機能の確認',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const AlarmTimer(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
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
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color:
                      Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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
