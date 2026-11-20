import 'dart:convert';

import 'package:http/http.dart' as http;

/// How long the chocolate bought through Ko-fi covers the server costs of LoudVector's
/// apps: counted on loudvector.com, and passed on at /api/chocolate by this app's own
/// Worker (worker.js). The footer's chocolate button says it.
class Chocolate {
  const Chocolate(this.until, this.daysLeft);

  /// The day the money runs out (a date; noon UTC so it never slips a day).
  final DateTime until;

  /// Whole days from now until then; below zero once it has run out.
  final int daysLeft;

  static Future<Chocolate?>? _loading;

  /// Asked once per visit; null if it can't say (offline, or the counter is down).
  static Future<Chocolate?> load() => _loading ??= _fetch();

  static Future<Chocolate?> _fetch() async {
    try {
      final res = await http.get(Uri.base.resolve('/api/chocolate')).timeout(const Duration(seconds: 10));
      return res.statusCode == 200 ? parse(jsonDecode(res.body)) : null;
    } catch (_) {
      return null;
    }
  }

  /// The counter's answer, { "until": "2027-03-04", "daysLeft": 103 }, or null.
  static Chocolate? parse(Object? json) {
    if (json is! Map) return null;
    final until = json['until'];
    final days = json['daysLeft'];
    if (until is! String || days is! num || !RegExp(r'^\d{4}-\d\d-\d\d$').hasMatch(until)) return null;
    return Chocolate(DateTime.parse('${until}T12:00:00Z'), days.floor());
  }

  /// The button's words: weeks, a date when under two weeks, out of pocket once it has run
  /// out, or the plain ask when it isn't known.
  static String words(Chocolate? c) {
    if (c == null) return '🍫 If you like it, buy me chocolate.';
    if (c.daysLeft < 0) {
      return "🍫 At the moment I'm covering the server costs out of pocket. If you like the app, buy me some chocolate.";
    }
    if (c.daysLeft < 14) {
      return '🍫 The chocolate bought so far covers the server costs until ${_day(c.until)}. If you like the app, buy me some.';
    }
    return '🍫 The chocolate bought so far covers the server costs for another ${c.daysLeft ~/ 7} weeks. If you like the app, buy me some.';
  }

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// "Friday 4 December".
  static String _day(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}
