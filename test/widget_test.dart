import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/link.dart';

import 'package:startup_namer/domains.dart';
import 'package:startup_namer/main.dart';
import 'package:startup_namer/tech_words.dart';

void main() {
  /// A tall phone-shaped window, so names aren't behind the notice or footer.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('each name says whether its .com is free', (tester) async {
    // The registry answers 404 for a name nobody has, 200 for one that's taken.
    final asked = <String>[];
    final client = MockClient((request) async {
      asked.add(request.url.toString());
      final name = request.url.pathSegments.last;
      return http.Response('', name.startsWith('a') ? 404 : 200);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    expect(find.text('Startup Names'), findsOneWidget);
    expect(find.textContaining('Checking'), findsWidgets);

    await tester.pump(const Duration(seconds: 30));
    expect(asked, isNotEmpty);
    expect(asked.first, startsWith('https://rdap.verisign.com/com/v1/domain/'));
    expect(find.textContaining(RegExp(r'\.com is (free|taken)')), findsWidgets);
  });

  testWidgets('a name that could not be checked can be asked again', (tester) async {
    tall(tester);
    var fail = true;
    final client = MockClient((request) async {
      if (fail) throw Exception('offline');
      return http.Response('', 404);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
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
    tall(tester);
    var busy = true;
    var asked = 0;
    final client = MockClient((request) async {
      asked++;
      return http.Response('', busy ? 429 : 404);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
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
    tall(tester);
    var hang = true;
    final client = MockClient((request) async {
      if (hang) await Future<void>.delayed(const Duration(seconds: 30));
      return http.Response('', 404);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
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
    tall(tester);
    var fail = true;
    final client = MockClient((request) async {
      if (fail) throw Exception('offline');
      return http.Response('', 404);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
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
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('The .com check'), findsNothing);
    }
    await tester.pump(const Duration(minutes: 2));
  });

  testWidgets('notices say when the registry limits checks, or answers with errors', (tester) async {
    var status = 429;
    final client = MockClient((request) async => http.Response('', status));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
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
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
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
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
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
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await tester.tap(find.text('Mixed order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Noun + adjective: RiverBright'));
    await tester.pumpAndSettle();
    expect(find.text('Noun + adjective'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
  });

  Iterable<String> titles(WidgetTester tester) =>
      tester.widgetList<ListTile>(find.byType(ListTile)).map((tile) => (tile.title as Text).data!);

  testWidgets('one word makes one-word names, with no word order or same first letter', (tester) async {
    tall(tester);
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await tester.tap(find.text('One word'));
    await tester.pump(const Duration(seconds: 1));
    expect(titles(tester), isNotEmpty);
    expect(titles(tester).every((title) => RegExp(r'^[A-Z][a-z]+$').hasMatch(title)), isTrue, reason: '${titles(tester)}');
    FilterChip chip(String label) => tester.widget<FilterChip>(find.ancestor(of: find.text(label), matching: find.byType(FilterChip)));
    expect(chip('Mixed order').onSelected, isNull);
    expect(chip('Same letter').onSelected, isNull);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('twists can be picked, start all ticked, and twist every name', (tester) async {
    tall(tester);
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await tester.tap(find.text('Twist spelling'));
    await tester.pumpAndSettle();
    expect(find.text('Like Tumblr: paper → papr, bundle → bundl'), findsOneWidget);
    final boxes = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(boxes.every((box) => box.value!), isTrue);
    for (final twist in ['Drop a vowel', '-ight to -ite', 'c to k', 'Double the last letter']) {
      await tester.tap(find.text(twist));
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Twist: i to y'), findsOneWidget);
    expect(titles(tester), isNotEmpty);
    expect(titles(tester).every((title) => title.contains('y')), isTrue, reason: '${titles(tester)}');

    await tester.tap(find.text('Twist: i to y'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No twists'));
    await tester.pumpAndSettle();
    expect(find.text('Twist spelling'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('endings go on the last word of every name', (tester) async {
    tall(tester);
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await tester.tap(find.text('One word'));
    await tester.pump();
    await tester.tap(find.text('Add ending'));
    await tester.pumpAndSettle();
    expect(find.text('Like Spotify or Jetify'), findsOneWidget);
    expect(find.text('Like GitHub or JetHub'), findsOneWidget);
    for (final ending in ['-ly', '-io', '-ster', '-sy', '-hub']) {
      await tester.tap(find.text(ending));
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Ending -ify'), findsOneWidget);
    expect(titles(tester), isNotEmpty);
    expect(titles(tester).every((title) => title.endsWith('ify')), isTrue, reason: '${titles(tester)}');
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('with the same first letter, both words of every name start alike', (tester) async {
    tall(tester);
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await tester.tap(find.text('Same letter'));
    await tester.pump(const Duration(seconds: 1));
    expect(titles(tester), isNotEmpty);
    for (final title in titles(tester)) {
      final capitals = RegExp('[A-Z]').allMatches(title).map((match) => match[0]).toList();
      expect(capitals, hasLength(2), reason: title);
      expect(capitals.first, capitals.last, reason: title);
    }
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('tapping a name saves it, and the saved list shows it', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
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
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
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

  testWidgets('the footer links to buying chocolate, and Built by LoudVector links to loudvector.com', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    expect(find.text('Built by'), findsOneWidget);
    expect(find.bySemanticsLabel('Built by LoudVector'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(2)); // The icon and the |LoudVector> lockup.
    final builtBy = tester.widget<Link>(find.ancestor(of: find.text('Built by'), matching: find.byType(Link)));
    expect(builtBy.uri.toString(), 'https://loudvector.com');
    expect(builtBy.target, LinkTarget.blank);
    const chocolate = '🍫 If you like it, buy me chocolate.';
    expect(find.text(chocolate), findsOneWidget);
    expect(find.ancestor(of: find.text(chocolate), matching: find.byType(OutlinedButton)), findsOneWidget);
    final link = tester.widget<Link>(find.ancestor(of: find.text(chocolate), matching: find.byType(Link)));
    expect(link.uri.toString(), 'https://ko-fi.com/loudvector');
    expect(link.target, LinkTarget.blank);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('on a wide screen the app keeps to a column down the middle', (tester) async {
    tester.view.physicalSize = const Size(3840, 2160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    final list = tester.getRect(find.byType(Scaffold).first);
    expect(list.width, 720);
    expect(list.center.dx, 1920);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('on a phone the app uses the whole width', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    expect(tester.getRect(find.byType(Scaffold).first).width, 375);
    await tester.pump(const Duration(seconds: 30));
  });

  /// Opens the domain picker from the chip showing [current], ticks [ends], and closes it.
  Future<void> pickTlds(WidgetTester tester, String current, List<String> ends) async {
    await tester.tap(find.text(current));
    await tester.pumpAndSettle();
    expect(find.text('Domains to check'), findsOneWidget);
    for (final end in ends) {
      await tester.tap(find.text(end));
      await tester.pump();
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  testWidgets('picking TLDs checks each with its own registry, and shows a status per TLD', (tester) async {
    tall(tester);
    final asked = <String>[];
    final client = MockClient((request) async {
      asked.add(request.url.toString());
      return http.Response('', request.url.host == 'rdap.verisign.com' ? 404 : 200);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await pickTlds(tester, '.com', ['.ai', '.dev']);
    expect(find.text('.com +2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));

    expect(asked.where((url) => url.startsWith('https://rdap.verisign.com/com/v1/domain/') && url.endsWith('.com')), isNotEmpty);
    expect(asked.where((url) => url.startsWith('https://rdap.identitydigital.services/rdap/domain/') && url.endsWith('.ai')), isNotEmpty);
    expect(asked.where((url) => url.startsWith('https://pubapi.registry.google/rdap/domain/') && url.endsWith('.dev')), isNotEmpty);
    // Each name shows each ending, with the full sentence as its tooltip.
    final first = tester.widget<Text>(find.descendant(of: find.byType(ListTile).first, matching: find.byType(Text)).first).data!.toLowerCase();
    expect(find.byTooltip('$first.com is free'), findsOneWidget);
    expect(find.byTooltip('$first.ai is taken: tap for details'), findsOneWidget);
    expect(find.byTooltip('$first.dev is taken: tap for details'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('one registry failing leaves the others alone, and the notice names it', (tester) async {
    tall(tester);
    var down = true;
    final client = MockClient((request) async {
      if (down && request.url.host == 'rdap.identitydigital.services') throw Exception('offline');
      return http.Response('', 404);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await pickTlds(tester, '.com', ['.ai']);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text("The .ai check can't reach the registry"), findsOneWidget);
    expect(find.textContaining("can't connect to rdap.identitydigital.services"), findsOneWidget);
    final first = tester.widget<Text>(find.descendant(of: find.byType(ListTile).first, matching: find.byType(Text)).first).data!.toLowerCase();
    expect(find.byTooltip('$first.com is free'), findsOneWidget);
    expect(find.byTooltip("Couldn't check $first.ai: tap to retry"), findsOneWidget);
    down = false; // Then it answers again, and the checks finish.
    await tester.pump(const Duration(minutes: 3));
  });

  testWidgets('.com and .net share Verisign, and its notice names both', (tester) async {
    var fail = true;
    final client = MockClient((request) async {
      if (fail) throw Exception('offline');
      return http.Response('', 404);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await pickTlds(tester, '.com', ['.net']);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text("The .com and .net checks can't reach the registry"), findsOneWidget);
    fail = false; // Then Verisign answers again, and the checks finish.
    await tester.pump(const Duration(minutes: 3));
    expect(find.textContaining("can't reach the registry"), findsNothing);
    // With the notice gone, more names fit: let their checks finish too.
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('the last TLD ticked can\'t be unticked', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await tester.tap(find.text('.com'));
    await tester.pumpAndSettle();
    final com = tester.widget<CheckboxListTile>(find.ancestor(of: find.text('.com').last, matching: find.byType(CheckboxListTile)));
    expect(com.value, isTrue);
    expect(com.onChanged, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('the footer links to the FAQ, in a tab of its own', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    final faq = tester.widget<Link>(find.ancestor(of: find.text('FAQ'), matching: find.byType(Link)));
    // A full address: a bare "faq" would be taken for a screen inside the app (/#faq).
    expect(faq.uri!.hasScheme, isTrue);
    expect(faq.uri!.path, '/faq');
    expect(faq.target, LinkTarget.blank);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('tapping a taken domain shows what its registry says, and links to its site', (tester) async {
    tall(tester);
    final client = MockClient((request) async {
      final domain = request.url.pathSegments.last;
      final body = '{"events": [{"eventAction": "registration", "eventDate": "2019-07-10T12:00:00Z"}, '
          '{"eventAction": "expiration", "eventDate": "2099-07-10T12:00:00Z"}], '
          '"entities": [{"roles": ["registrar"], "vcardArray": ["vcard", [["fn", {}, "text", "GoDaddy.com, LLC"]]]}], '
          '"nameservers": [{"ldhName": "NS1.ATOM.COM"}], "ldhName": "$domain"}';
      return http.Response(body, 200);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await tester.pump(const Duration(seconds: 5));
    final taken = find.textContaining('.com is taken').first;
    final domain = tester.widget<Text>(taken).data!.split(' ').first;
    await tester.tap(taken);
    await tester.pumpAndSettle();
    expect(find.text(domain), findsOneWidget);
    expect(find.text('10 July 2019'), findsOneWidget);
    expect(find.text('GoDaddy.com, LLC'), findsOneWidget);
    expect(find.textContaining('with Atom, a domain marketplace'), findsOneWidget);
    final visit = tester.widget<Link>(find.ancestor(of: find.text('Visit $domain'), matching: find.byType(Link)));
    expect(visit.uri.toString(), 'https://$domain');
    expect(visit.target, LinkTarget.blank);
    expect(find.byIcon(Icons.favorite), findsNothing); // Tapping the domain doesn't save the name.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets("a twisted name's details say who has its usual spelling", (tester) async {
    tall(tester);
    // The twisted names (all with a y here) are free; their usual spellings
    // (none with a y) are taken, with a record.
    final client = MockClient((request) async {
      final domain = request.url.pathSegments.last;
      if (domain.contains('y')) return http.Response('', 404);
      return http.Response(
          '{"events": [{"eventAction": "registration", "eventDate": "1998-03-02T12:00:00Z"}], '
          '"entities": [{"roles": ["registrar"], "vcardArray": ["vcard", [["fn", {}, "text", "Example Registrar"]]]}], '
          '"ldhName": "$domain"}',
          200);
    });
    await tester.pumpWidget(NamerApp(checker: DomainChecker(client: client)));
    await tester.tap(find.text('One word'));
    await tester.pump();
    await tester.tap(find.text('Twist spelling'));
    await tester.pumpAndSettle();
    for (final twist in ['Drop a vowel', '-ight to -ite', 'c to k', 'Double the last letter']) {
      await tester.tap(find.text(twist));
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    final free = find.textContaining('.com is free').first;
    final domain = tester.widget<Text>(free).data!.split(' ').first;
    final spoken = domain.replaceFirst('y', 'i');
    await tester.tap(free);
    await tester.pumpAndSettle();
    expect(find.text(domain), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Sounds like $spoken'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('$spoken is taken, so people who hear the name'), findsOneWidget);
    expect(find.text('2 March 1998'), findsOneWidget);
    expect(find.text('Example Registrar'), findsOneWidget);
    final visit = tester.widget<Link>(find.ancestor(of: find.text('Visit $spoken'), matching: find.byType(Link)));
    expect(visit.uri.toString(), 'https://$spoken');
    expect(find.text('Visit $domain'), findsNothing); // Free: nothing there to visit.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
  });
}
