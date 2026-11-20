import 'package:flutter_test/flutter_test.dart';
import 'package:startup_namer/chocolate.dart';

void main() {
  test('the counter\'s answer, or nothing for anything else', () {
    final c = Chocolate.parse({'until': '2027-03-04', 'daysLeft': 103});
    expect(c?.daysLeft, 103);
    expect(c?.until, DateTime.utc(2027, 3, 4, 12));
    expect(Chocolate.parse({'until': 'soon', 'daysLeft': 3}), isNull);
    expect(Chocolate.parse({'until': '2027-03-04'}), isNull);
    expect(Chocolate.parse('nonsense'), isNull);
  });

  test('the button\'s words: weeks, a date, out of pocket, or the plain ask', () {
    expect(Chocolate.words(null), '🍫 If you like it, buy me chocolate.');
    expect(Chocolate.words(Chocolate(DateTime.utc(2027, 3, 4, 12), 103)),
        '🍫 The chocolate bought so far covers the server costs for another 14 weeks. If you like the app, buy me some.');
    expect(Chocolate.words(Chocolate(DateTime.utc(2026, 12, 4, 12), 10)),
        '🍫 The chocolate bought so far covers the server costs until Friday 4 December. If you like the app, buy me some.');
    expect(Chocolate.words(Chocolate(DateTime.utc(2026, 11, 16, 12), -5)),
        "🍫 At the moment I'm covering the server costs out of pocket. If you like the app, buy me some chocolate.");
  });
}
