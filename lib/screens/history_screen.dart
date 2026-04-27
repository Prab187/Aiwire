import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/article.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/article_card.dart';

class HistoryScreen extends StatefulWidget {
  final AppTheme theme;
  const HistoryScreen({super.key, required this.theme});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Article> _history = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final items = await HistoryService.getHistory();
    setState(() { _history = items; _loading = false; });
  }

  Future<void> _clear() async {
    await HistoryService.clear();
    setState(() => _history = []);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Icon(Icons.arrow_back, color: t.primary)),
            const SizedBox(width: 16),
            Text('Recently Read', style: GoogleFonts.sourceSerif4(
                fontSize: 22, fontWeight: FontWeight.w600, color: t.primary)),
            const Spacer(),
            if (_history.isNotEmpty)
              GestureDetector(
                onTap: _clear,
                child: Text('Clear', style: GoogleFonts.inter(
                    fontSize: 13, color: t.muted,
                    decoration: TextDecoration.underline,
                    decorationColor: t.muted)),
              ),
          ]),
        ),
        Divider(height: 1, color: t.divider),
        Expanded(child: _loading
          ? Center(child: CircularProgressIndicator(color: t.primary, strokeWidth: 1))
          : _history.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.history, color: t.muted, size: 48),
                const SizedBox(height: 16),
                Text('No reading history', style: GoogleFonts.sourceSerif4(
                    fontSize: 20, fontWeight: FontWeight.w600, color: t.primary)),
                const SizedBox(height: 8),
                Text('Articles you read will appear here',
                    style: GoogleFonts.inter(color: t.muted, fontSize: 13)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 40),
                itemCount: _history.length,
                itemBuilder: (context, i) => ArticleCard(article: _history[i], theme: t),
              )),
      ])),
    );
  }
}
