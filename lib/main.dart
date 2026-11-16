import 'dart:async';
import 'dart:collection';

import 'package:english_words/english_words.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'names.dart';

void main() => runApp(NamerApp(checker: DotComChecker()));

class NamerApp extends StatelessWidget {
  const NamerApp({super.key, required this.checker});

  final DotComChecker checker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Startup Name Generator',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: RandomWords(checker: checker),
    );
  }
}

/// What the .com registry says about a name's .com.
enum DotCom { checking, free, taken, unknown }

/// Asks the .com registry (Verisign's public RDAP service, which any web page may
/// ask) whether each name's .com is registered: it answers 404 for one nobody has.
/// A few at a time, a moment apart, and each name once.
class DotComChecker extends ChangeNotifier {
  DotComChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, DotCom> _found = {};
  final Queue<String> _waiting = Queue();
  int _running = 0;
  static const _atOnce = 2;
  static const _gap = Duration(milliseconds: 150);

  /// The answer so far for `name` (letters only, like "neatchip"), asking if it's new.
  DotCom statusOf(String name) {
    final known = _found[name];
    if (known != null) return known;
    _found[name] = DotCom.checking;
    _waiting.add(name);
    _next();
    return DotCom.checking;
  }

  void _next() {
    while (_running < _atOnce && _waiting.isNotEmpty) {
      final name = _waiting.removeFirst();
      _running++;
      _check(name).whenComplete(() async {
        await Future<void>.delayed(_gap);
        _running--;
        _next();
      });
    }
  }

  Future<void> _check(String name) async {
    DotCom answer;
    try {
      final response = await _client
          .get(Uri.https('rdap.verisign.com', '/com/v1/domain/$name.com'))
          .timeout(const Duration(seconds: 10));
      answer = switch (response.statusCode) {
        404 => DotCom.free,
        200 => DotCom.taken,
        _ => DotCom.unknown,
      };
    } catch (_) {
      answer = DotCom.unknown;
    }
    _found[name] = answer;
    notifyListeners();
  }

  /// Asks again about a name that couldn't be checked.
  void retry(String name) {
    if (_found[name] != DotCom.unknown) return;
    _found.remove(name);
    statusOf(name);
    notifyListeners();
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({super.key, required this.checker});

  final DotComChecker checker;

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _saved = <WordPair>{};
  final _biggerFont = const TextStyle(fontSize: 18);
  final _scroll = ScrollController();
  bool _tech = false;
  bool _longer = false;
  late Iterator<WordPair> _pairs = _newPairs();

  Iterator<WordPair> _newPairs() => namePairs(longer: _longer, tech: _tech).iterator;

  /// A fresh list from the top with the words chosen. Saved names stay.
  void _setWords({bool? tech, bool? longer}) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _tech = tech ?? _tech;
      _longer = longer ?? _longer;
      _pairs = _newPairs();
      _suggestions.clear();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Saved Suggestions')),
          body: ListenableBuilder(
            listenable: widget.checker,
            builder: (context, _) => ListView(
              children: ListTile.divideTiles(
                context: context,
                tiles: _saved.map((pair) => _tile(pair)),
              ).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _pushSaved,
            tooltip: 'Saved Suggestions',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Tech words'),
                  tooltip: 'One word of each name is a tech word, like quark or pixel',
                  selected: _tech,
                  onSelected: (on) => _setWords(tech: on),
                ),
                FilterChip(
                  label: const Text('Longer words'),
                  tooltip: 'Two-syllable words too, like river or signal',
                  selected: _longer,
                  onSelected: (on) => _setWords(longer: on),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.checker,
        builder: (context, _) => ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, i) {
            if (i.isOdd) return const Divider();
            final index = i ~/ 2;
            while (index >= _suggestions.length && _pairs.moveNext()) {
              _suggestions.add(_pairs.current);
            }
            return _buildRow(_suggestions[index]);
          },
        ),
      ),
    );
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _saved.contains(pair);
    return _tile(
      pair,
      trailing: Icon(
        alreadySaved ? Icons.favorite : Icons.favorite_border,
        color: alreadySaved ? Colors.red : null,
        semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
      ),
      onTap: () => setState(() {
        if (!_saved.remove(pair)) _saved.add(pair);
      }),
    );
  }

  /// A name, with whether its .com is free under it.
  ListTile _tile(WordPair pair, {Widget? trailing, VoidCallback? onTap}) {
    final domain = '${pair.asLowerCase}.com';
    final status = widget.checker.statusOf(pair.asLowerCase);
    final colours = Theme.of(context).colorScheme;
    final (text, colour, icon) = switch (status) {
      DotCom.checking => ('Checking $domain…', colours.outline, Icons.hourglass_empty),
      DotCom.free => ('$domain is free', Colors.green.shade700, Icons.check_circle),
      DotCom.taken => ('$domain is taken', colours.outline, Icons.block),
      DotCom.unknown => ("Couldn't check $domain: tap to retry", colours.error, Icons.refresh),
    };
    return ListTile(
      title: Text(pair.asPascalCase, style: _biggerFont),
      subtitle: GestureDetector(
        onTap: status == DotCom.unknown ? () => widget.checker.retry(pair.asLowerCase) : null,
        child: Row(
          children: [
            Icon(icon, size: 16, color: colour),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: TextStyle(color: colour))),
          ],
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
