# Cookhelper

チーム向けFlutter調理アシスタントアプリケーション

## システム要件

### 必須ソフトウェア

1. **Flutter SDK**
   - バージョン: 3.9.2 以上
   - インストール: [Flutter公式インストールガイド](https://docs.flutter.dev/get-started/install)

2. **Dart SDK**
   - Flutter SDKに含まれています（^3.9.2）

3. **開発環境（いずれか一つ）**
   - Visual Studio Code + Flutter拡張機能

## セットアップ手順

### 1. リポジトリのクローン

```bash
git clone https://github.com/tobakuro/Cookhelper.git
cd Cookhelper
```

### 2. 依存関係のインストール

```bash
flutter pub get
```

### 3. Flutter環境の確認

```bash
flutter doctor
```

すべての項目が✓になればOK

### 4. 実行

**デバッグモードで実行:**
```bash
flutter run
```

**特定のプラットフォームで実行:**
```bash
# Android
flutter run -d android

# Web
flutter run -d web
```

## 開発用コマンド

### テストの実行
```bash
flutter test
```

### コード分析
```bash
flutter analyze
```

### アプリのビルド

**リリースビルド:**
```bash
# Android APK
flutter build apk --release

# Web
flutter build web --release
```

## プロジェクト構造

```
lib/
├── main.dart                    # エントリーポイント
├── screens/                    # 画面ウィジェット
│   ├── home_screen.dart
│   └── recipe_screen.dart
├── services/                   # ビジネスロジック・API
│   ├── gemini_service.dart
│   ├── speech_service.dart
│   └── tts_service.dart
└── widgets/                    # 再利用可能なウィジェット
    ├── recipe_card.dart
    ├── step_indicator.dart
    └── voice_command_button.dart
```

## トラブルシューティング

### よくある問題

1. **`flutter doctor` でエラーが出る場合**
   - Android Studio やXcode の最新版をインストール
   - Android SDK の適切なバージョンをダウンロード
   - 環境変数PATHの設定を確認

2. **依存関係のエラー**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **ビルドエラー**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## チーム開発ガイドライン

### コード品質
- このプロジェクトでは `flutter_lints` を使用しています
- コミット前に `flutter analyze` を実行してください

### Git ワークフロー
1. 作業用ブランチを作成: `git checkout -b feature/your-feature-name`
2. 変更をコミット: `git commit -m "Add: your feature description"`
3. プルリクエストを作成してレビューを依頼

## 参考リンク

- [Flutter公式ドキュメント](https://docs.flutter.dev/)
- [Dart言語ガイド](https://dart.dev/guides)
- [Flutter開発ツール](https://docs.flutter.dev/tools)
