import 'package:flutter/material.dart';

/// アプリ全体で使用する色定義
/// 基調: 黒・白・オレンジ
class AppColors {
  // プライマリカラー（オレンジ）
  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryLight = Color(0xFFFF8A3D);
  static const Color primaryDark = Color(0xFFE55A00);

  // 背景色
  static const Color background = Colors.white;
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // テキスト色
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);

  // ボーダー・ディバイダー
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // アクセントカラー（控えめに使用）
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);

  // アイコンコンテナ背景
  static const Color iconContainerBg = Color(0xFFFFF3E0);

  // カード背景
  static const Color cardBg = Colors.white;

  // AppBar
  static const Color appBarBg = Color(0xFFFF6B00);
  static const Color appBarFg = Colors.white;

  // ボタン
  static const Color buttonPrimary = Color(0xFFFF6B00);
  static const Color buttonSecondary = Color(0xFF1A1A1A);
  static const Color buttonDisabled = Color(0xFFBDBDBD);

  // ステップ・タイマー関連
  static const Color stepBg = Color(0xFFFFF8F0);
  static const Color stepBorder = Color(0xFFFFE0B2);
  static const Color timerBg = Color(0xFFFFF3E0);
  static const Color timerBorder = Color(0xFFFFCC80);

  // 音声認識
  static const Color listeningBg = Color(0xFFFFF3E0);
  static const Color listeningActive = Color(0xFFFF6B00);
  static const Color listeningInactive = Color(0xFF999999);

  // 星評価
  static const Color star = Color(0xFFFF6B00);
}
