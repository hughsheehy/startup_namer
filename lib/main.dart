import 'dart:async';
import 'dart:collection';

import 'package:english_words/english_words.dart';
import 'package:flutter/services.dart';
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
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: RandomWords(checker: checker),
    );
  }
}

/// What the .com registry says about a name's .com.
enum DotCom { checking, free, taken, unknown }

/// Asks the .com registry (Verisign's public RDAP service, which any web page may
/// ask) whether each name's .com is registered: it answers 404 for one nobody has.
/// Two at a time, a moment apart, and each name once.
///
/// The registry publishes no limit, but may refuse a browser that asks too often
/// (429 Too Many Requests). Then, or if it can't be reached, the checks slow
/// down, waiting twice as long each time up to a minute (or as long as the
/// registry says), and speed up again once it answers.
class DotComChecker extends ChangeNotifier {
  DotComChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, DotCom> _found = {};
  final Queue<String> _waiting = Queue();
  int _running = 0;
  Timer? _pause;
  Duration _backOff = Duration.zero;
  static const _atOnce = 2;
  static const _gap = Duration(milliseconds: 250);
  static const _longestBackOff = Duration(minutes: 1);

  /// Whether the registry has pushed back, or not answered, and checks are slower.
  bool get slowedDown => _backOff > Duration.zero;

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
    if (_pause != null) return;
    while (_running < _atOnce && _waiting.isNotEmpty) {
      final name = _waiting.removeFirst();
      _running++;
      _check(name).whenComplete(() {
        _running--;
        _pause ??= Timer(_gap + _backOff, () {
          _pause = null;
          _next();
        });
      });
    }
  }

  Future<void> _check(String name) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.https('rdap.verisign.com', '/com/v1/domain/$name.com'))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Offline, or a refusal the page isn't let read (a browser hides an answer
      // that lacks the header saying any page may read it), so slow down too.
      _slowDown();
      _answer(name, DotCom.unknown);
      return;
    }
    switch (response.statusCode) {
      case 404 || 200:
        _backOff = Duration.zero;
        _answer(name, response.statusCode == 404 ? DotCom.free : DotCom.taken);
      case 429 || 503:
        // Asked too often, or too busy: ask again, after a pause.
        final seconds = int.tryParse(response.headers['retry-after'] ?? '');
        _slowDown(seconds == null ? null : Duration(seconds: seconds));
        _waiting.addFirst(name);
        notifyListeners();
      default:
        _answer(name, DotCom.unknown);
    }
  }

  void _slowDown([Duration? asked]) {
    final doubled = _backOff == Duration.zero ? const Duration(seconds: 2) : _backOff * 2;
    _backOff = asked ?? (doubled > _longestBackOff ? _longestBackOff : doubled);
  }

  void _answer(String name, DotCom answer) {
    _found[name] = answer;
    notifyListeners();
  }

  /// Asks again, now, about a name that couldn't be checked.
  void retry(String name) {
    if (_found[name] != DotCom.unknown) return;
    _found[name] = DotCom.checking;
    _waiting.addFirst(name);
    _pause?.cancel();
    _pause = null;
    _next();
    notifyListeners();
  }

  /// Forgets the names not yet asked about, as when the list starts again, so
  /// names no longer shown aren't asked about. Any that show again are asked then.
  void dropWaiting() {
    for (final name in _waiting) {
      _found.remove(name);
    }
    _waiting.clear();
  }

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
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
  WordOrder _order = WordOrder.mixed;
  String _letter = ''; // Every name starts with this, if set.
  String _word = ''; // Every name has this word, if set...
  Place _place = Place.either; // ...here.
  late Iterator<WordPair> _pairs = _newPairs();

  Iterator<WordPair> _newPairs() => namePairs(
        longer: _longer,
        tech: _tech,
        order: _order,
        letter: _letter,
        word: _word,
        place: _place,
      ).iterator;

  /// A fresh list from the top with the options chosen. Saved names stay.
  void _setWords({bool? tech, bool? longer, WordOrder? order, String? letter, String? word, Place? place}) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    widget.checker.dropWaiting();
    setState(() {
      _tech = tech ?? _tech;
      _longer = longer ?? _longer;
      _order = order ?? _order;
      _letter = letter ?? _letter;
      _word = word ?? _word;
      _place = place ?? _place;
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

  Future<void> _pickLetter() async {
    final letter = await showDialog<String>(
      context: context,
      builder: (context) => _LetterDialog(letter: _letter),
    );
    if (letter != null) _setWords(letter: letter);
  }

  Future<void> _pickWord() async {
    final chosen = await showDialog<(String, Place)>(
      context: context,
      builder: (context) => _WordDialog(word: _word, place: _place, order: _order),
    );
    if (chosen != null) _setWords(word: chosen.$1, place: chosen.$2);
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
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
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
                MenuAnchor(
                  menuChildren: [
                    for (final order in WordOrder.values)
                      MenuItemButton(
                        leadingIcon: Icon(order == _order ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                        onPressed: () => _setWords(order: order),
                        child: Text('${order.label}: ${order.example}'),
                      ),
                  ],
                  builder: (context, menu, _) => FilterChip(
                    avatar: const Icon(Icons.swap_horiz),
                    showCheckmark: false,
                    label: Text(_order.label),
                    tooltip: 'Which kind of word goes first',
                    selected: _order != WordOrder.mixed,
                    onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
                  ),
                ),
                FilterChip(
                  avatar: const Icon(Icons.sort_by_alpha),
                  showCheckmark: false,
                  label: Text(_letter.isEmpty ? 'Starting letter' : 'Starts with ${_letter.toUpperCase()}'),
                  tooltip: 'Names that start with a letter of your choice',
                  selected: _letter.isNotEmpty,
                  onSelected: (_) => _pickLetter(),
                  onDeleted: _letter.isEmpty ? null : () => _setWords(letter: ''),
                  deleteButtonTooltipMessage: 'Any letter',
                ),
                FilterChip(
                  avatar: const Icon(Icons.edit),
                  showCheckmark: false,
                  label: Text(switch ((_word, _place)) {
                    ('', _) => 'Your own word',
                    (final word, Place.first) => '${_capital(word)} first',
                    (final word, Place.second) => '${_capital(word)} second',
                    (final word, Place.either) => 'With ${_capital(word)}',
                  }),
                  tooltip: 'A word of your own in every name',
                  selected: _word.isNotEmpty,
                  onSelected: (_) => _pickWord(),
                  onDeleted: _word.isEmpty ? null : () => _setWords(word: ''),
                  deleteButtonTooltipMessage: 'No word of my own',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.checker,
              builder: (context, _) => ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, i) {
                  final index = i ~/ 2;
                  while (index >= _suggestions.length && _pairs.moveNext()) {
                    _suggestions.add(_pairs.current);
                  }
                  if (index < _suggestions.length) {
                    return i.isOdd ? const Divider() : _buildRow(_suggestions[index]);
                  }
                  // The options make only so many names, or none.
                  if (i != 2 * _suggestions.length) return null;
                  return _suggestions.isEmpty
                      ? const ListTile(
                          leading: Icon(Icons.search_off),
                          title: Text('No names fit these options'),
                          subtitle: Text('Try another starting letter, word order or place for your word.'),
                        )
                      : const ListTile(
                          leading: Icon(Icons.done_all),
                          title: Text("That's every name these options make"),
                        );
                },
              ),
            ),
          ),
        ],
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
      DotCom.checking when widget.checker.slowedDown =>
        ('Checking $domain… (the registry is busy, so more slowly)', colours.outline, Icons.hourglass_empty),
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

String _capital(String word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

/// Picks the letter names start with: answers it, '' for any letter, or nothing
/// if cancelled.
class _LetterDialog extends StatelessWidget {
  const _LetterDialog({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Names start with'),
      content: SizedBox(
        width: 300,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final c in 'abcdefghijklmnopqrstuvwxyz'.split(''))
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(44),
                  padding: EdgeInsets.zero,
                  backgroundColor: c == letter ? colours.primaryContainer : null,
                ),
                onPressed: () => Navigator.pop(context, c),
                child: Text(c.toUpperCase(), style: const TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Any letter')),
      ],
    );
  }
}

/// Picks a word of the user's own for every name, and where it goes: answers
/// them ('' for no word), or nothing if cancelled.
class _WordDialog extends StatefulWidget {
  const _WordDialog({required this.word, required this.place, required this.order});

  final String word;
  final Place place;
  final WordOrder order;

  @override
  State<_WordDialog> createState() => _WordDialogState();
}

class _WordDialogState extends State<_WordDialog> {
  late final _text = TextEditingController(text: widget.word);
  late var _place = widget.place;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _use() => Navigator.pop(context, (_text.text.toLowerCase(), _place));

  @override
  Widget build(BuildContext context) {
    final word = _text.text.isEmpty ? 'Yours' : _capital(_text.text.toLowerCase());
    final first = '$word${widget.order.second}', second = '${widget.order.first}$word';
    return AlertDialog(
      title: const Text('Your own word'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'A word for every name', hintText: 'volt, say'),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]'))],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _use(),
          ),
          const SizedBox(height: 20),
          const Text('Where it goes'),
          const SizedBox(height: 8),
          SegmentedButton<Place>(
            segments: [for (final place in Place.values) ButtonSegment(value: place, label: Text(place.label))],
            selected: {_place},
            showSelectedIcon: false,
            onSelectionChanged: (chosen) => setState(() => _place = chosen.single),
          ),
          const SizedBox(height: 12),
          Text(
            'Like ${switch (_place) {
              Place.first => first,
              Place.second => second,
              Place.either => '$first or $second',
            }}, in ${widget.order.label.toLowerCase()}',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _use, child: const Text('Use it')),
      ],
    );
  }
}
