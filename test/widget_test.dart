import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/link.dart';

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
    expect(find.text('Startup Names'), findsOneWidget);
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
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('when the registry says too many, checks wait and ask again', (tester) async {
    var busy = true;
    var asked = 0;
    final client = MockClient((request) async {
      asked++;
      return http.Response('', busy ? 429 : 404);
    });
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('more slowly for now'), findsWidgets);
    expect(find.textContaining("Couldn't check"), findsNothing); // Not given up on...
    final soFar = asked;
    await tester.pump(const Duration(seconds: 1));
    expect(asked, soFar); // ...but not asked again straight away.

    busy = false;
    await tester.pump(const Duration(minutes: 2));
    expect(find.textContaining('is free'), findsWidgets);
    expect(find.textContaining('more slowly for now'), findsNothing);
  });

  testWidgets('a notice says when the registry is slow, then not answering, and goes when it answers', (tester) async {
    var hang = true;
    final client = MockClient((request) async {
      if (hang) await Future<void>.delayed(const Duration(seconds: 30));
      return http.Response('', 404);
    });
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('The .com check is slow'), findsNothing); // Not yet...

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('The .com check is slow'), findsOneWidget); // ...but soon.

    await tester.pump(const Duration(seconds: 7));
    expect(find.text("The .com check isn't getting answers"), findsOneWidget);
    expect(find.textContaining('getting no reply from the registry (rdap.verisign.com) within 10 seconds'), findsOneWidget);
    expect(find.textContaining('checks in a row have had trouble so far'), findsOneWidget);

    hang = false;
    await tester.tap(find.text('Check again'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('is free'), findsWidgets);
    expect(find.text("The .com check isn't getting answers"), findsNothing);
    await tester.pump(const Duration(minutes: 2));
  });

  testWidgets('a notice says when the registry can\'t be reached', (tester) async {
    var fail = true;
    final client = MockClient((request) async {
      if (fail) throw Exception('offline');
      return http.Response('', 404);
    });
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("The .com check can't reach the registry"), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Check again'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("The .com check can't reach the registry"), findsNothing);
    await tester.pump(const Duration(minutes: 2));
  });

  testWidgets('one failed check alone brings no notice', (tester) async {
    var failures = 1;
    final client = MockClient((request) async {
      if (failures-- > 0) throw Exception('blip');
      return http.Response('', 404);
    });
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('The .com check'), findsNothing);
    }
    await tester.pump(const Duration(minutes: 2));
  });

  testWidgets('notices say when the registry limits checks, or answers with errors', (tester) async {
    var status = 429;
    final client = MockClient((request) async => http.Response('', status));
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('The registry is limiting checks'), findsOneWidget);
    expect(find.textContaining('"too many requests"'), findsOneWidget);

    status = 500;
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('The registry is answering with errors'), findsOneWidget);
    expect(find.textContaining('answering with error 500'), findsOneWidget);
    await tester.pump(const Duration(minutes: 2));
  });

  testWidgets('a starting letter makes every name start with it', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.tap(find.text('Starting letter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Q'));
    await tester.pumpAndSettle();
    expect(find.text('Starts with Q'), findsOneWidget);
    final titles = tester.widgetList<ListTile>(find.byType(ListTile)).map((tile) => (tile.title as Text).data!);
    expect(titles, isNotEmpty);
    expect(titles.every((title) => title.startsWith('Q')), isTrue, reason: '$titles');
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('a word of your own goes in every name, where asked', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.tap(find.text('Your own word'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'volt');
    await tester.tap(find.text('Second'));
    await tester.pump();
    expect(find.textContaining('Like BrightVolt'), findsOneWidget);
    await tester.tap(find.text('Use it'));
    await tester.pumpAndSettle();
    expect(find.text('Volt second'), findsOneWidget);
    final titles = tester.widgetList<ListTile>(find.byType(ListTile)).map((tile) => (tile.title as Text).data!);
    expect(titles.every((title) => title.endsWith('Volt')), isTrue, reason: '$titles');

    // Volt can't go first in a name starting with Q.
    await tester.tap(find.text('Volt second'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First'));
    await tester.tap(find.text('Use it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starting letter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Q'));
    await tester.pumpAndSettle();
    expect(find.text('No names fit these options'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('the word order menu changes the order', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    await tester.tap(find.text('Mixed order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noun + adjective: RiverBright'));
    await tester.pumpAndSettle();
    expect(find.text('Noun + adjective'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
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

  testWidgets('the footer says Built by LoudVector, with the logo, and links to buying chocolate', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DotComChecker(client: client)));
    expect(find.text('Built by'), findsOneWidget);
    expect(find.bySemanticsLabel('Built by LoudVector'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(2)); // The icon and the |LoudVector> lockup.
    expect(find.text('Buy me chocolate'), findsOneWidget);
    final link = tester.widget<Link>(find.ancestor(of: find.text('Buy me chocolate'), matching: find.byType(Link)));
    expect(link.uri.toString(), 'https://ko-fi.com/irishfolklore');
    expect(link.target, LinkTarget.blank);
    await tester.pump(const Duration(seconds: 30));
  });
}
