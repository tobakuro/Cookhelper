import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ← Web判定に必要
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'screens/login_screen.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  dynamic database;

  // ★ Web では SQLite を初期化しない
  if (!kIsWeb) {
    database = await initDatabase();
  }

  runApp(MyApp(database: database));
}

Future<Database> initDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'cookhelper.db');

  return await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE,
          password TEXT
        )
      ''');
    },
  );
}

class MyApp extends StatelessWidget {
  final dynamic database;

  const MyApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CookHelper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LoginScreen(database: database),
    );
  }
}
