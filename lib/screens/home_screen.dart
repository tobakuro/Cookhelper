import 'package:flutter/material.dart';
import 'recipe_search_screen.dart';
import 'recipe_generate_screen.dart';
import 'favorites_screen.dart';
import 'cooking_screen.dart';
import 'audio_record_test_screen.dart';
// 笘� 1. GoogleLiveAPITestScreen 縺ｮ繧､繝ｳ繝昴�ｼ繝医ｒ霑ｽ蜉�
import 'google_live_api_test_screen.dart'; 
import 'gemini_live_test_screen.dart';

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
      // Scrollable縺ｫ縺吶ｋ縺溘ａ縲，enter繧鱈istView縺ｫ螟画峩縺吶ｋ縺薙→縺梧耳螂ｨ縺輔ｌ縺ｾ縺吶′縲�
      // 莉雁屓縺ｯ譌｢蟄倥�ｮ讒矩�縺ｫ蜷医ｏ縺帙※Column縺ｫ繝｡繝九Η繝ｼ繧定ｿｽ蜉�縺励∪縺吶�
      body: Center(
        child: SingleChildScrollView( // 笘� 鬆�逶ｮ縺悟｢励∴縺溘◆繧√√せ繧ｯ繝ｭ繝ｼ繝ｫ蜿ｯ閭ｽ縺ｫ縺吶ｋ
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
                '譁咏炊繧偵ｂ縺｣縺ｨ讌ｽ縺励￥!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '鬟滓攝繧呈､懃ｴ｢縲�髻ｳ螢ｰ縺ｧ繝ｬ繧ｷ繝斐ｒ謫堺ｽ�',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              
              // --- 譌｢蟄倥�ｮ繝｡繝九Η繝ｼ ---
              // 繝ｬ繧ｷ繝疲､懃ｴ｢
              _buildMenuButton(
                context,
                icon: Icons.search,
                label: '繝ｬ繧ｷ繝疲､懃ｴ｢',
                description: '譁咏炊蜷阪〒讀懃ｴ｢',
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

              // 繝ｬ繧ｷ繝皮函謌�
              _buildMenuButton(
                context,
                icon: Icons.auto_awesome,
                label: '繝ｬ繧ｷ繝皮函謌�',
                description: '謇区戟縺｡縺九ｉ繝ｬ繧ｷ繝斐ｒ菴懈��',
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

              // 髻ｳ螢ｰ謫堺ｽ懊Δ繝ｼ繝�
              _buildMenuButton(
                context,
                icon: Icons.mic,
                label: '髻ｳ螢ｰ謫堺ｽ懊Δ繝ｼ繝�',
                description: '繝上Φ繧ｺ繝輔Μ繝ｼ縺ｧ謫堺ｽ�',
                icon: Icons.science,
                label: 'Gemini Live テスト',
                description: 'Gemini Live API接続テスト',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GeminiLiveTestScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // 縺頑ｰ励↓蜈･繧�
              _buildMenuButton(
                context,
                icon: Icons.favorite,
                label: '縺頑ｰ励↓蜈･繧�',
                description: '菫晏ｭ倥＠縺溘Ξ繧ｷ繝�',
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

              // 髻ｳ螢ｰ骭ｲ髻ｳ繝�繧ｹ繝�
              _buildMenuButton(
                context,
                icon: Icons.mic_external_on,
                label: '髻ｳ螢ｰ骭ｲ髻ｳ繝�繧ｹ繝�',
                description: '繝槭う繧ｯ骭ｲ髻ｳ讖溯�ｽ縺ｮ繝�繧ｹ繝�',
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
              
              // 笘� 2. 譁ｰ縺励＞繝｡繝九Η繝ｼ繝懊ち繝ｳ縺ｮ霑ｽ蜉�
              _buildMenuButton(
                context,
                icon: Icons.cloud_upload, // API謗･邯壹ｒ遉ｺ縺吶い繧､繧ｳ繝ｳ
                label: 'Google Live API 繝�繧ｹ繝�', 
                description: '繝ｪ繧｢繝ｫ繧ｿ繧､繝�髻ｳ螢ｰ隱崎ｭ倥�ｮ謗･邯壹ユ繧ｹ繝�', 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoogleLiveAPITestScreen(),
                    ),
                  );
                },
              ),
              // --- 繝｡繝九Η繝ｼ邨ゅｏ繧� ---

            ],
          ),
        ),
      ),
    );
  }

  // _buildMenuButton繝｡繧ｽ繝�繝峨�ｯ逵∫払
  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    // ... (蜈�縺ｮ _buildMenuButton 縺ｮ螳溯｣�)
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