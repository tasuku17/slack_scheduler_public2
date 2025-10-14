import 'dart:convert';
import 'package:http/http.dart' as http;

class SlackService {
  final String botToken;
  final String channelId;

  SlackService({required this.botToken, required this.channelId});

  /// メッセージ送信
  Future<String?> postMessage(String text) async {
    final response = await http.post(
      Uri.parse('https://slack.com/api/chat.postMessage'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $botToken',
      },
      body: jsonEncode({'channel': channelId, 'text': text}),
    );

    final data = jsonDecode(response.body);
    if (data['ok'] == true) {
      print('✅ メッセージ送信成功: ${data['ts']}');
      return data['ts']; // ← このtsを保存すれば編集・削除できる
    } else {
      print('❌ メッセージ送信失敗: ${data['error']}');
      return null;
    }
  }

  /// メッセージ編集
  Future<void> updateMessage(String ts, String newText) async {
    final response = await http.post(
      Uri.parse('https://slack.com/api/chat.update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $botToken',
      },
      body: jsonEncode({'channel': channelId, 'ts': ts, 'text': newText}),
    );

    final data = jsonDecode(response.body);
    if (data['ok'] == true) {
      print('✏️ メッセージ編集成功');
    } else {
      print('❌ 編集失敗: ${data['error']}');
    }
  }

  /// メッセージ削除
  Future<void> deleteMessage(String ts) async {
    final response = await http.post(
      Uri.parse('https://slack.com/api/chat.delete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $botToken',
      },
      body: jsonEncode({'channel': channelId, 'ts': ts}),
    );

    final data = jsonDecode(response.body);
    if (data['ok'] == true) {
      print('🗑️ メッセージ削除成功');
    } else {
      print('❌ 削除失敗: ${data['error']}');
    }
  }
}
