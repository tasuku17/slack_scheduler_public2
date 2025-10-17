import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // .env ファイルを読み込む
  final slackWebhookUrl = dotenv.env['SLACK_WEBHOOK_URL'];
  if (slackWebhookUrl == null || slackWebhookUrl.isEmpty) {
    throw Exception("SLACK_WEBHOOK_URL が .env に設定されていません");
  }

  runApp(SlackApp(slackWebhookUrl: slackWebhookUrl));
}

class SlackApp extends StatelessWidget {
  final String slackWebhookUrl;

  const SlackApp({super.key, required this.slackWebhookUrl});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slack送信アプリ',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP')],
      home: MessageForm(slackWebhookUrl: slackWebhookUrl),
    );
  }
}

class MessageForm extends StatefulWidget {
  final String slackWebhookUrl;
  const MessageForm({super.key, required this.slackWebhookUrl});

  @override
  State<MessageForm> createState() => _MessageFormState();
}

class _MessageFormState extends State<MessageForm> {
  late String slackWebhookUrl;
  DateTime? startDate;
  bool _isSending = false;

  final templates = {
    '月': {'time': '8:00-10:00', 'area': '全面', 'note': ''},
    '火': {'time': '8:30-10:00', 'area': '半面', 'note': '月の奇数回目は無し'},
    '水': {'time': '9:00-10:00', 'area': '全面', 'note': ''},
    '木_奇数': {'time': '8:00-10:00', 'area': '全面', 'note': '奇数週(木曜)'},
    '木_偶数': {'time': '8:00-10:00', 'area': '半面', 'note': '偶数週(木曜)'},
    '金': {'time': '8:00-10:00', 'area': '全面', 'note': ''},
    '土': {'time': '16:30-19:00', 'area': '全面', 'note': '17:00までは半面'},
    '日_奇数': {'time': '13:00-18:00', 'area': '半面(17:00~全面)', 'note': '奇数週(日曜)'},
    '日_偶数': {'time': '13:00-16:00', 'area': '半面', 'note': '偶数週(日曜)'},
  };

  List<Map<String, dynamic>> weekPlans = [];

  @override
  void initState() {
    super.initState();
    slackWebhookUrl = widget.slackWebhookUrl;
  }

  void _generateWeekPlans(DateTime date) {
    weekPlans.clear();
    for (int i = 0; i < 7; i++) {
      final day = date.add(Duration(days: i));
      final weekday = DateFormat('E', 'ja_JP').format(day);
      String key;
      if (weekday == '日')
        key = '日_奇数';
      else if (weekday == '木')
        key = '木_奇数';
      else
        key = weekday;

      final t = templates[key]!;

      weekPlans.add({
        'date': DateFormat('M/d', 'ja_JP').format(day),
        'weekday': weekday,
        'time': t['time'],
        'area': t['area'],
        'note': t['note'],
        'send': true,
        'isOddSunday': weekday == '日' ? true : null,
        'isOddThursday': weekday == '木' ? true : null,
        'preview':
            "${DateFormat('M/d', 'ja_JP').format(day)}($weekday) ${t['time']} ${t['area']}${weekday == '土' ? '（経験者練習）' : ''}\n練習に参加されたい方は代と本名(フルネーム)をこのスレッドに記入してください",
      });
    }
    setState(() {});
  }

  void _updatePreview(int index) {
    final plan = weekPlans[index];
    String key;
    if (plan['weekday'] == '日')
      key = plan['isOddSunday'] == true ? '日_奇数' : '日_偶数';
    else if (plan['weekday'] == '木')
      key = plan['isOddThursday'] == true ? '木_奇数' : '木_偶数';
    else
      key = plan['weekday'];

    final t = templates[key]!;
    plan['time'] = t['time'];
    plan['area'] = t['area'];
    plan['preview'] =
        "${plan['date']}(${plan['weekday']}) ${t['time']} ${t['area']}${plan['weekday'] == '土' ? '（経験者練習）' : ''}\n練習に参加されたい方は代と本名(フルネーム)をこのスレッドに記入してください";

    setState(() {});
  }

  Future<void> _sendWeekToSlack() async {
    setState(() => _isSending = true);
    for (final plan in weekPlans.where((p) => p['send'])) {
      await http.post(
        Uri.parse(slackWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': plan['preview']}),
      );
      await Future.delayed(const Duration(milliseconds: 400));
    }
    setState(() => _isSending = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('選択された日程を送信しました！')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slack送信フォーム')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  startDate == null
                      ? '📅 開始日を選択してください'
                      : '選択日：${DateFormat('M月d日 (E)', 'ja_JP').format(startDate!)}',
                ),
                ElevatedButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2026),
                      locale: const Locale('ja', 'JP'),
                    );
                    if (date != null) {
                      startDate = date;
                      _generateWeekPlans(date);
                    }
                  },
                  child: const Text('日付選択'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: weekPlans.length,
                itemBuilder: (context, index) {
                  final plan = weekPlans[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: plan['send'],
                                onChanged: (val) =>
                                    setState(() => plan['send'] = val!),
                              ),
                              Text(
                                "${plan['date']}(${plan['weekday']})",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (plan['weekday'] == '木')
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('奇数週'),
                                  selected: plan['isOddThursday'] == true,
                                  onSelected: (v) {
                                    plan['isOddThursday'] = true;
                                    _updatePreview(index);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('偶数週'),
                                  selected: plan['isOddThursday'] == false,
                                  onSelected: (v) {
                                    plan['isOddThursday'] = false;
                                    _updatePreview(index);
                                  },
                                ),
                              ],
                            ),
                          if (plan['weekday'] == '日')
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('奇数週'),
                                  selected: plan['isOddSunday'] == true,
                                  onSelected: (v) {
                                    plan['isOddSunday'] = true;
                                    _updatePreview(index);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('偶数週'),
                                  selected: plan['isOddSunday'] == false,
                                  onSelected: (v) {
                                    plan['isOddSunday'] = false;
                                    _updatePreview(index);
                                  },
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Text(
                            "プレビュー:\n${plan['preview']}",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: Text(_isSending ? '送信中...' : '選択日をSlackに送信'),
                onPressed: _isSending ? null : _sendWeekToSlack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
