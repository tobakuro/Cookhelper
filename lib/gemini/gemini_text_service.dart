import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Gemini APIを使用したテキスト生成サービス
/// レシピ検索・生成など、シンプルなテキスト生成タスクに使用
class GeminiTextService {
  late final GenerativeModel _model;

  GeminiTextService() {
    final apiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }

    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey,
    );
  }

  /// テキストコンテンツを生成
  ///
  /// [prompt] 生成するテキストのプロンプト
  /// 戻り値: 生成されたテキスト
  Future<String> generateContent(String prompt) async {
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini API');
      }

      return response.text!;
    } on GenerativeAIException catch (e) {
      throw Exception('Gemini API error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// ストリーミングでテキストコンテンツを生成
  ///
  /// [prompt] 生成するテキストのプロンプト
  /// 戻り値: テキストチャンクのストリーム
  Stream<String> generateContentStream(String prompt) async* {
    try {
      final content = [Content.text(prompt)];
      final response = _model.generateContentStream(content);

      await for (final chunk in response) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          yield chunk.text!;
        }
      }
    } on GenerativeAIException catch (e) {
      throw Exception('Gemini API stream error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}
