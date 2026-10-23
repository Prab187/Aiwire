import 'news_item.dart';

const stationName = 'Kampus Radio';

String _join(List<String> items) {
  if (items.length <= 1) return items.join();
  return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

String _when(DateTime? published, DateTime now) {
  if (published == null) return '';
  final days = now.difference(published).inDays;
  if (days <= 0) return ' today';
  if (days == 1) return ' yesterday';
  if (days < 7) return ' $days days ago';
  return '';
}

String introScript(int count) =>
    "You're tuned in to $stationName. $count ${count == 1 ? 'story' : 'stories'} on AI in schools. Here we go.";

String storyScript(NewsItem it, int index, int total, {DateTime? now}) {
  final parts = <String>['Story ${index + 1} of $total.'];
  if (it.hasSchoolAndAi) parts.add('${it.school}, and ${_join(it.aiTools)}.');
  parts.add('${it.title.replaceAll(RegExp(r'[.!?]+$'), '')}.');
  parts.add('From ${it.source}${_when(it.published, now ?? DateTime.now())}.');
  if (it.summary.isNotEmpty) parts.add(it.summary);
  return parts.join(' ');
}

const outroScript = "That's the latest. Pull down to refresh for more. You've been listening to $stationName.";
