import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ← Web判定に必要

import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final dynamic database; // ← Webではnullになるので dynamic に変更

  const LoginScreen({super.key, required this.database});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _login() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    // ★ Web のときは仮ログイン
    if (kIsWeb) {
      if (username == 'test' && password == '24a') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Web版: ログイン失敗')));
      }
      return;
    }

    // ★ Web 以外（Windows/Android）のときだけ SQLite を使う
    final result = await widget.database.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (result.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ログイン失敗')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
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
            ElevatedButton(onPressed: _login, child: const Text('ログイン')),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RegisterScreen(database: widget.database),
                  ),
                );
              },
              child: const Text('新規登録はこちら'),
            ),
          ],
        ),
      ),
    );
  }
}
