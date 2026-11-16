import 'package:english_words/english_words.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'brand.dart';
import 'domains.dart';
import 'names.dart';

void main() => runApp(NamerApp(checker: DomainChecker()));

class NamerApp extends StatelessWidget {
  const NamerApp({super.key, required this.checker});

  final DomainChecker checker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Startup Names · LoudVector',
      theme: Brand.theme(Brightness.light),
      darkTheme: Brand.theme(Brightness.dark),
      builder: (context, app) => _Column(child: app!),
      home: RandomWords(checker: checker),
    );
  }
}

/// Keeps the app to a column down the middle of a wide screen, as on a phone,
/// rather than stretched across a big monitor. Narrower screens get all of it.
class _Column extends StatelessWidget {
  const _Column({required this.child});

  final Widget child;
  static const maxWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    final screen = MediaQuery.of(context);
    final wide = screen.size.width > maxWidth;
    final width = wide ? maxWidth : screen.size.width;
    return ColoredBox(
      color: wide ? colours.surfaceContainer : colours.surface,
      child: Center(
        child: SizedBox(
          width: width,
          // So everything inside, dialogs included, sizes to the column.
          child: MediaQuery(
            data: screen.copyWith(size: Size(width, screen.size.height)),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: wide ? BorderSide(color: colours.outlineVariant) : BorderSide.none,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({super.key, required this.checker});

  final DomainChecker checker;

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
  bool _more = false;
  WordOrder _order = WordOrder.mixed;
  String _letter = ''; // Every name starts with this, if set.
  String _word = ''; // Every name has this word, if set...
  Place _place = Place.either; // ...here.
  List<Tld> _tlds = [tlds.first]; // The domain endings checked: .com to start.
  late Iterator<WordPair> _pairs = _newPairs();

  Iterator<WordPair> _newPairs() => namePairs(
        longer: _longer,
        more: _more,
        tech: _tech,
        order: _order,
        letter: _letter,
        word: _word,
        place: _place,
      ).iterator;

  /// A fresh list from the top with the options chosen. Saved names stay.
  void _setWords({bool? tech, bool? longer, bool? more, WordOrder? order, String? letter, String? word, Place? place}) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    widget.checker.dropWaiting();
    setState(() {
      _tech = tech ?? _tech;
      _longer = longer ?? _longer;
      _more = more ?? _more;
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

  Future<void> _pickTlds() async {
    final chosen = await showDialog<List<Tld>>(
      context: context,
      builder: (context) => _TldDialog(chosen: _tlds),
    );
    if (chosen == null) return;
    // The names stay; only what's checked changes.
    widget.checker.dropWaiting();
    setState(() => _tlds = chosen);
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
        title: const KetTitle('Startup Names'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _pushSaved,
            tooltip: 'Saved Suggestions',
          ),
        ],
      ),
      // The options and any notice scroll away with the names, so the names get
      // the room on a small screen.
      body: ListenableBuilder(
        listenable: widget.checker,
        builder: (context, _) => CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
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
                    FilterChip(
                      label: const Text('More words'),
                      tooltip: 'Over twice as many words, some less common, like tundra or velocity',
                      selected: _more,
                      onSelected: (on) => _setWords(more: on),
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
                    FilterChip(
                      avatar: const Icon(Icons.public),
                      showCheckmark: false,
                      label: Text('${_tlds.first}${_tlds.length > 1 ? ' +${_tlds.length - 1}' : ''}'),
                      tooltip: 'Which domain endings to check, like .com or .ai',
                      selected: !(_tlds.length == 1 && _tlds.single.name == 'com'),
                      onSelected: (_) => _pickTlds(),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _TroubleNotice(checker: widget.checker)),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
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
                }),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BrandFooter(),
    );
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _saved.contains(pair);
    return _tile(
      pair,
      trailing: Icon(
        alreadySaved ? Icons.favorite : Icons.favorite_border,
        color: alreadySaved ? Theme.of(context).colorScheme.primary : null,
        semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
      ),
      onTap: () => setState(() {
        if (!_saved.remove(pair)) _saved.add(pair);
      }),
    );
  }

  /// A name, with whether its domains are free under it: a sentence for one TLD
  /// ("neatchip.com is free"), a short status per TLD for several.
  ListTile _tile(WordPair pair, {Widget? trailing, VoidCallback? onTap}) {
    final name = pair.asLowerCase;
    return ListTile(
      title: Text(pair.asPascalCase, style: _biggerFont),
      subtitle: _tlds.length == 1
          ? _domain(name, _tlds.single, brief: false)
          : Wrap(spacing: 14, runSpacing: 2, children: [for (final tld in _tlds) _domain(name, tld, brief: true)]),
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// Whether `name` is free under [tld]: in a sentence, or [brief]ly as the
  /// ending alone, with the sentence as its tooltip. One that couldn't be
  /// checked is asked again when tapped.
  Widget _domain(String name, Tld tld, {required bool brief}) {
    final domain = '$name.${tld.name}';
    final status = widget.checker.statusOf(name, tld);
    final colours = Theme.of(context).colorScheme;
    final green = Theme.of(context).brightness == Brightness.dark ? Colors.green.shade300 : Colors.green.shade700;
    final (sentence, colour, icon) = switch (status) {
      Availability.checking when widget.checker.registryFor(tld).slowedDown =>
        ('Checking $domain… (more slowly for now)', colours.outline, Icons.hourglass_empty),
      Availability.checking => ('Checking $domain…', colours.outline, Icons.hourglass_empty),
      Availability.free => ('$domain is free', green, Icons.check_circle),
      Availability.taken => ('$domain is taken', colours.outline, Icons.block),
      Availability.unknown => ("Couldn't check $domain: tap to retry", colours.error, Icons.refresh),
    };
    final row = Row(
      mainAxisSize: brief ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(icon, size: brief ? 15 : 16, color: colour),
        SizedBox(width: brief ? 3 : 6),
        if (brief) Text('$tld', style: TextStyle(color: colour)) else Flexible(child: Text(sentence, style: TextStyle(color: colour))),
      ],
    );
    return GestureDetector(
      onTap: status == Availability.unknown ? () => widget.checker.retry(name, tld) : null,
      child: brief ? Tooltip(message: sentence, child: Semantics(label: sentence, excludeSemantics: true, child: row)) : row,
    );
  }
}

/// A notice above the list while a registry's checks keep going wrong, saying
/// what's wrong. It goes once a check there gets a quick answer again.
class _TroubleNotice extends StatelessWidget {
  const _TroubleNotice({required this.checker});

  final DomainChecker checker;

  @override
  Widget build(BuildContext context) {
    final troubled = checker.troubled;
    if (troubled == null) return const SizedBox.shrink();
    final registry = troubled.host;
    const carryOn = "Checks carry on, more slowly, and names that couldn't be checked say so.";
    final n = troubled.problemsInARow;
    final trouble = troubled.trouble;
    // "The .com check is…", or "The .com and .net checks are…" for a registry
    // that answers for more than one TLD.
    final endings = troubled.endings;
    final one = endings.length < 2;
    final which = one ? 'The ${endings.firstOrNull ?? 'domain'} check' : 'The ${endings.sublist(0, endings.length - 1).join(', ')} and ${endings.last} checks';
    final described = switch (trouble) {
      Trouble.none => null,
      Trouble.slow => (
          Icons.hourglass_bottom,
          '$which ${one ? 'is' : 'are'} slow',
          'The registry ($registry) is taking more than ${RegistryChecker.slowAfter.inSeconds} seconds to answer, '
              'when it usually answers in under a second. Names are still being checked, just slowly.',
        ),
      Trouble.noReply => (
          Icons.cloud_off,
          "$which ${one ? "isn't" : "aren't"} getting answers",
          'Checks are getting no reply from the registry ($registry) within ${RegistryChecker.timeout.inSeconds} '
              'seconds. It may be down or overloaded, or this connection very slow. $carryOn',
        ),
      Trouble.cantConnect => (
          Icons.wifi_off,
          "$which can't reach the registry",
          "Checks can't connect to $registry. This device may be offline, this network may block it, "
              'or the registry may be turning this browser away. $carryOn',
        ),
      Trouble.limited => (
          Icons.front_hand,
          'The registry is limiting checks',
          '$registry is answering "too many requests" or "too busy", so checks now wait '
              '${troubled.waitBetweenTries.inSeconds} seconds between tries, until it lets them through again.',
        ),
      Trouble.errors => (
          Icons.error_outline,
          'The registry is answering with errors',
          '$registry is answering with error ${troubled.lastError}, probably a fault at its end. $carryOn',
        ),
    };
    if (described == null) return const SizedBox.shrink();
    final (icon, title, problem) = described;
    final detail = '$problem\n$n checks in a row have had trouble so far.';
    final colours = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final serious = trouble.serious;
    final (background, foreground) = serious
        ? (colours.errorContainer, colours.onErrorContainer)
        : (colours.secondaryContainer, colours.onSecondaryContainer);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall?.copyWith(color: foreground, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(detail, style: text.bodyMedium?.copyWith(color: foreground)),
                      if (troubled.unchecked > 0 && trouble != Trouble.limited)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: checker.retryAll,
                            style: TextButton.styleFrom(foregroundColor: foreground),
                            child: const Text('Check again'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _capital(String word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

/// Picks the domain endings to check, at least one: answers them in the order
/// of [tlds], or nothing if cancelled.
class _TldDialog extends StatefulWidget {
  const _TldDialog({required this.chosen});

  final List<Tld> chosen;

  @override
  State<_TldDialog> createState() => _TldDialogState();
}

class _TldDialogState extends State<_TldDialog> {
  late final _chosen = {...widget.chosen};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Domains to check'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: 320,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final tld in tlds)
              CheckboxListTile(
                value: _chosen.contains(tld),
                title: Text('$tld'),
                subtitle: Text(tld.registry),
                dense: true,
                // At least one, or there'd be nothing to check.
                onChanged: _chosen.length == 1 && _chosen.contains(tld)
                    ? null
                    : (on) => setState(() => on! ? _chosen.add(tld) : _chosen.remove(tld)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, [for (final tld in tlds) if (_chosen.contains(tld)) tld]),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

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
