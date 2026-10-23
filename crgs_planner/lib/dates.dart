const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole days from [b] to [a] (a - b), ignoring clock time and daylight saving.
int dayDiff(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseIso(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// The school day the app should show: today, or the next weekday at the
/// weekend and after 4pm.
DateTime viewDay(DateTime now) {
  var d = dateOnly(now);
  if (now.weekday > 5 || now.hour >= 16) {
    do {
      d = DateTime(d.year, d.month, d.day + 1);
    } while (d.weekday > 5);
  }
  return d;
}

String longDate(DateTime d) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return '${days[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1]}';
}

String shortDate(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[d.weekday - 1]} ${d.day} ${monthShort[d.month - 1]}';
}
