import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'package:startup_namer/main.dart';
import 'package:startup_namer/tech_words.dart';

void main() {
  testWidgets('each name says whether its .com is free', (tester) async {
    // The registry answers 404 for a name nobody has, 200 for one that's taken.
    final asked = <String>[];
    final client = MockClient((request) async {
      asked.add(request.url.toString());
      final name = request.url.pathSegments.last;
      return http.Response('', name.startsWith('a') ? 404 : 200);
    });
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    expect(find.text('Startup Name Generator'), findsOneWidget);
    expect(find.textContaining('Checking'), findsWidgets);

    await tester.pump(const Duration(seconds: 30));
    expect(asked, isNotEmpty);
    expect(asked.first, startsWith('https://rdap.verisign.com/com/v1/domain/'));
    expect(find.textContaining(RegExp(r'\.com is (free|taken)')), findsWidgets);
  });

  testWidgets('a name that could not be checked can be asked again', (tester) async {
    var fail = true;
    final client = MockClient((request) async {
      if (fail) throw Exception('offline');
      return http.Response('', 404);
    });
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.pump(const Duration(seconds: 30));
    final retry = find.textContaining("Couldn't check").first;
    expect(retry, findsOneWidget);

    fail = false;
    await tester.tap(retry);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('is free'), findsWidgets);
  });

  testWidgets('tapping a name saves it, and the saved list shows it', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.byTooltip('Saved Suggestions'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Suggestions'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the Tech words switch makes a fresh list of tech names, and saved names stay', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();

    await tester.tap(find.text('Tech words'));
    await tester.pump(const Duration(seconds: 1));
    final first = tester.widget<Text>(find.descendant(of: find.byType(ListTile).first, matching: find.byType(Text)).first).data!;
    expect(techWords.any((word) => first.toLowerCase().contains(word)), isTrue, reason: first);
    expect(find.byIcon(Icons.favorite), findsNothing); // The saved name isn't in the new list...

    await tester.tap(find.byTooltip('Saved Suggestions'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget); // ...but is still saved.
    await tester.pump(const Duration(seconds: 1));
  });
}
