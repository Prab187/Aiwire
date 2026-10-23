import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../palette.dart';
import '../radio/ai_schools.dart';
import '../radio/news_item.dart';
import '../radio/radio_controller.dart';
import '../widgets.dart';

String timeAgo(DateTime? t, DateTime now) {
  if (t == null) return '';
  final d = now.difference(t);
  if (d.inMinutes < 2) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  return '${d.inDays} days ago';
}

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key, required this.radio});
  final RadioController radio;

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  late final TextEditingController _school = TextEditingController(text: widget.radio.mySchool);

  @override
  void initState() {
    super.initState();
    // Stories are fetched the first time this tab opens, not when the app starts.
    widget.radio.load();
  }

  @override
  void dispose() {
    _school.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open that story.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.radio,
      builder: (context, _) {
        final r = widget.radio;
        final now = DateTime.now();
        final pairs = schoolAiPairs(r.items);
        return RefreshIndicator(
          onRefresh: () => r.load(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: pagePadding,
            children: [
              _station(context, r, now),
              const SizedBox(height: 16),
              if (r.current != null) ...[_nowPlaying(context, r), const SizedBox(height: 16)],
              _board(context, pairs),
              const SizedBox(height: 16),
              if (r.items.isNotEmpty) ...[_queue(context, r), const SizedBox(height: 16)],
              _tune(context, r),
              const SizedBox(height: 16),
              const Note('Headlines come from public news feeds (BBC News, Schools Week and other trusted sources) and are read by your phone\'s voice. Schools and AI names are spotted automatically and can be wrong, so open the story to check. Unofficial: not made or endorsed by Colchester Royal Grammar School.'),
            ],
          ),
        );
      },
    );
  }

  Widget _station(BuildContext context, RadioController r, DateTime now) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? Brand.heroDark : Brand.purple;
    final fg = dark ? const Color(0xFFF3EBFB) : Colors.white;
    final loading = r.state == RadioState.loading;
    final updated = r.updated == null ? '' : (r.fromCache ? 'Saved ${timeAgo(r.updated, now)}' : 'Updated ${timeAgo(r.updated, now)}');
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Column(children: [
        Container(
          width: double.infinity,
          color: bg,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Equaliser(playing: r.playing, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI RADIO', style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        Text('Which school got which AI', style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: serif)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous story',
                    iconSize: 34,
                    color: fg,
                    onPressed: r.items.isEmpty ? null : r.previous,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: loading
                        ? Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: fg)))
                        : IconButton.filled(
                            key: const Key('radio-play'),
                            tooltip: r.playing ? 'Pause' : 'Play',
                            style: IconButton.styleFrom(backgroundColor: fg, foregroundColor: bg),
                            iconSize: 40,
                            onPressed: r.toggle,
                            icon: Icon(r.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Next story',
                    iconSize: 34,
                    color: fg,
                    onPressed: r.items.isEmpty ? null : r.next,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  loading ? 'Tuning in…' : (r.items.isEmpty ? '' : '${r.index + 1} of ${r.items.length}${updated.isEmpty ? '' : ' · $updated'}'),
                  style: TextStyle(color: fg.withValues(alpha: 0.9), fontSize: 13),
                ),
              ),
              if (r.message != null) ...[
                const SizedBox(height: 8),
                Center(child: Text(r.message!, textAlign: TextAlign.center, style: TextStyle(color: fg, fontSize: 14))),
                if (r.state == RadioState.error)
                  Center(
                    child: TextButton(onPressed: () => r.load(force: true), style: TextButton.styleFrom(foregroundColor: fg), child: const Text('Try again')),
                  ),
              ],
            ],
          ),
        ),
        Container(height: 5, color: dark ? Brand.greenLight : Brand.green),
      ]),
    );
  }

  Widget _chips(BuildContext context, NewsItem it, {bool mine = false}) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (mine)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: cs.secondary, borderRadius: BorderRadius.circular(99)),
            child: Text('Your school', style: TextStyle(color: cs.onSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        if (it.school != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(99)),
            child: Text(it.school!, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        for (final t in it.aiTools)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: cs.secondary), borderRadius: BorderRadius.circular(99)),
            child: Text(t, style: TextStyle(color: cs.secondary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _nowPlaying(BuildContext context, RadioController r) {
    final it = r.current!;
    return Panel(
      title: r.playing ? 'Now playing' : 'Up next',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(it.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 6),
          Note('${it.source}${it.published == null ? '' : ' · ${timeAgo(it.published, DateTime.now())}'}'),
          const SizedBox(height: 10),
          _chips(context, it, mine: mentionsSchool(it, r.mySchool)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => _open(it.url), icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Read the story')),
        ],
      ),
    );
  }

  Widget _board(BuildContext context, List<({String school, String tool, NewsItem story})> pairs) {
    final cs = Theme.of(context).colorScheme;
    return Panel(
      title: 'Who got which AI',
      child: pairs.isEmpty
          ? const Note('No school and AI pairs spotted yet. They show up here when a story names both.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in pairs.take(8))
                  InkWell(
                    onTap: () => _open(p.story.url),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(p.school, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Icon(Icons.arrow_forward_rounded, size: 18, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(border: Border.all(color: cs.secondary), borderRadius: BorderRadius.circular(99)),
                            child: Text(p.tool, style: TextStyle(color: cs.secondary, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                const Note('Spotted automatically in headlines. Tap a row to read the story.'),
              ],
            ),
    );
  }

  Widget _queue(BuildContext context, RadioController r) {
    final cs = Theme.of(context).colorScheme;
    return Panel(
      title: 'Playlist',
      child: Column(
        children: [
          for (var i = 0; i < r.items.length; i++)
            InkWell(
              onTap: () => r.playAt(i),
              child: Container(
                color: i == r.index ? cs.primaryContainer.withValues(alpha: 0.5) : null,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 28, child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary))),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.items[i].title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Note(r.items[i].source),
                          if (r.items[i].hasSchoolAndAi) ...[const SizedBox(height: 4), _chips(context, r.items[i])],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tune(BuildContext context, RadioController r) {
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text('Tune the radio', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: serif, fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _school,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'My school',
              helperText: 'Stories about this school are played first.',
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              suffixIcon: IconButton(tooltip: 'Save school', icon: const Icon(Icons.check), onPressed: () => r.setSchool(_school.text)),
            ),
            onSubmitted: r.setSchool,
          ),
          const SizedBox(height: 14),
          const Text('Where in the world', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 'uk', label: Text('UK')), ButtonSegment(value: 'world', label: Text('Worldwide'))],
            selected: {r.store.data.radioScope},
            onSelectionChanged: (s) => r.setScope(s.first),
          ),
          const SizedBox(height: 14),
          const Text('Speed', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SegmentedButton<double>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 0.8, label: Text('Slow')), ButtonSegment(value: 1.0, label: Text('Normal')), ButtonSegment(value: 1.2, label: Text('Fast'))],
            selected: {r.rate},
            onSelectionChanged: (s) => r.setRate(s.first),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: () => r.load(force: true), icon: const Icon(Icons.refresh), label: const Text('Refresh stories')),
        ],
      ),
    );
  }
}

/// Four little bars that bounce while the radio is playing.
class Equaliser extends StatefulWidget {
  const Equaliser({super.key, required this.playing, required this.color});
  final bool playing;
  final Color color;

  @override
  State<Equaliser> createState() => _EqualiserState();
}

class _EqualiserState extends State<Equaliser> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Equaliser old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.playing && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => SizedBox(
          width: 34,
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 6,
                  height: widget.playing ? 8 + 24 * (0.5 + 0.5 * math.sin(_c.value * 2 * math.pi + i * 1.4)) : 8.0 + (i % 2) * 6,
                  decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(3)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
