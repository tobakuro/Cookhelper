import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class RegisterScreen extends StatefulWidget {
  final Database database;
  const RegisterScreen({super.key, required this.database});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _register() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    try {
      await widget.database.insert('users', {
        'username': username,
        'password': password,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登録が完了しました')));

      Navigator.pop(context); // ログイン画面に戻る
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登録に失敗しました（既に存在する可能性）')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ユーザー登録')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'ユーザー名'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'パスワード'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _register, child: const Text('登録')),
          ],
        ),
      ),
    );
  }
}
