import 'package:flutter/material.dart';
import '../gemini/gemini_live_service.dart';

class GeminiLiveTestScreen extends StatefulWidget {
  const GeminiLiveTestScreen({super.key});

  @override
  State<GeminiLiveTestScreen> createState() => _GeminiLiveTestScreenState();
}

class _GeminiLiveTestScreenState extends State<GeminiLiveTestScreen> {
  final GeminiLiveService _geminiService = GeminiLiveService();
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];
  bool _isConnected = false;
  bool _isConnecting = false;

  @override
  void dispose() {
    _messageController.dispose();
    _geminiService.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await _geminiService.connect();
      setState(() {
        _isConnected = true;
        _messages.add('[システム] 接続しました');
      });
    } catch (e) {
      setState(() {
        _messages.add('[エラー] 接続に失敗しました: $e');
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await _geminiService.disconnect();
    setState(() {
      _isConnected = false;
      _messages.add('[システム] 切断しました');
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メッセージを入力してください')),
      );
      return;
    }

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に接続してください')),
      );
      return;
    }

    final message = _messageController.text;
    setState(() {
      _messages.add('[送信] $message');
    });

    _geminiService.sendMessage(message);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Live API テスト'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 接続状態表示
            Card(
              color: _isConnected ? Colors.green.shade50 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.cancel,
                          color: _isConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected ? '接続中' : '未接続',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isConnected ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _isConnecting
                          ? null
                          : (_isConnected ? _disconnect : _connect),
                      child: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isConnected ? '切断' : '接続'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // メッセージ送信欄
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'メッセージ',
                      hintText: 'Gemini Live APIに送信するメッセージ',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isConnected ? _sendMessage : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // メッセージ履歴
            const Text(
              'メッセージ履歴',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '接続してメッセージを送信してください',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _messages[index],
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: _messages[index].startsWith('[エラー]')
                                    ? Colors.red
                                    : _messages[index].startsWith('[システム]')
                                        ? Colors.blue
                                        : Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
