import 'package:flutter/material.dart';

// エラーの原因になる import などをすべて削除しました
class CookingScreen extends StatelessWidget {
  const CookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cooking Assistant')),
      body: const Center(
        child: Text('ここに料理の指示が表示される予定です'),
      ),
    );
  }
}