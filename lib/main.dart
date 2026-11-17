import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/link.dart';

import 'brand.dart';
import 'domains.dart';
import 'names.dart';
import 'spelling.dart';

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
  final _suggestions = <Name>[];
  final _saved = <Name>{};
  final _biggerFont = const TextStyle(fontSize: 18);
  final _scroll = ScrollController();
  bool _tech = false;
  bool _longer = false;
  bool _more = false;
  bool _oneWord = false;
  Set<Twist> _twists = {};
  Set<Ending> _endings = {};
  bool _sameLetter = false;
  WordOrder _order = WordOrder.mixed;
  String _letter = ''; // Every name starts with this, if set.
  String _word = ''; // Every name has this word, if set...
  Place _place = Place.either; // ...here.
  List<Tld> _tlds = [tlds.first]; // The domain endings checked: .com to start.
  late Iterator<Name> _names = _newNames();

  Iterator<Name> _newNames() => suggestNames(
        longer: _longer,
        more: _more,
        tech: _tech,
        oneWord: _oneWord,
        twists: _twists,
        endings: _endings,
        sameLetter: _sameLetter,
        order: _order,
        letter: _letter,
        word: _word,
        place: _place,
      ).iterator;

  /// A fresh list from the top with the options chosen. Saved names stay.
  void _setWords({
    bool? tech,
    bool? longer,
    bool? more,
    bool? oneWord,
    Set<Twist>? twists,
    Set<Ending>? endings,
    bool? sameLetter,
    WordOrder? order,
    String? letter,
    String? word,
    Place? place,
  }) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    widget.checker.dropWaiting();
    setState(() {
      _tech = tech ?? _tech;
      _longer = longer ?? _longer;
      _more = more ?? _more;
      _oneWord = oneWord ?? _oneWord;
      _twists = twists ?? _twists;
      _endings = endings ?? _endings;
      _sameLetter = sameLetter ?? _sameLetter;
      _order = order ?? _order;
      _letter = letter ?? _letter;
      _word = word ?? _word;
      _place = place ?? _place;
      _names = _newNames();
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
                tiles: _saved.map((name) => _tile(name)),
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
      builder: (context) => _PickDialog<Tld>(
        title: 'Domains to check',
        options: tlds,
        chosen: _tlds,
        label: (tld) => '$tld',
        detail: (tld) => tld.registry,
        atLeastOne: true,
      ),
    );
    if (chosen == null) return;
    // The names stay; only what's checked changes.
    widget.checker.dropWaiting();
    setState(() => _tlds = chosen);
  }

  Future<void> _pickWord() async {
    final chosen = await showDialog<(String, Place)>(
      context: context,
      builder: (context) => _WordDialog(word: _word, place: _place, order: _order, oneWord: _oneWord),
    );
    if (chosen != null) _setWords(word: chosen.$1, place: chosen.$2);
  }

  Future<void> _pickTwists() async {
    final chosen = await showDialog<List<Twist>>(
      context: context,
      builder: (context) => _PickDialog<Twist>(
        title: 'Twist the spelling',
        note: 'One word of each name is spelled one of these ways.',
        options: Twist.values,
        // All of them, the first time.
        chosen: _twists.isEmpty ? Twist.values : _twists,
        label: (twist) => twist.label,
        detail: (twist) => 'Like ${twist.brand}: ${twist.example}',
        noneLabel: 'No twists',
      ),
    );
    if (chosen != null) _setWords(twists: chosen.toSet());
  }

  Future<void> _pickEndings() async {
    final chosen = await showDialog<List<Ending>>(
      context: context,
      builder: (context) => _PickDialog<Ending>(
        title: 'Add an ending',
        note: "The last word of each name gets one of these endings. They're best on one-word names.",
        options: Ending.values,
        chosen: _endings.isEmpty ? Ending.values : _endings,
        label: (ending) => ending.label,
        detail: (ending) => 'Like ${ending.brand} or ${Name([ending.apply('jet')!])}',
        noneLabel: 'No endings',
      ),
    );
    if (chosen != null) _setWords(endings: chosen.toSet());
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
                    FilterChip(
                      label: const Text('One word'),
                      tooltip: 'Names of one word, like Tumblr or Spotify: best with a twist or an ending',
                      selected: _oneWord,
                      onSelected: (on) => _setWords(oneWord: on),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.auto_fix_high),
                      showCheckmark: false,
                      label: Text(switch (_twists.length) {
                        0 => 'Twist spelling',
                        1 => 'Twist: ${_twists.single.label}',
                        final n => '$n twists',
                      }),
                      tooltip: 'One word spelled another way, like Tumblr or Lyft',
                      selected: _twists.isNotEmpty,
                      onSelected: (_) => _pickTwists(),
                      onDeleted: _twists.isEmpty ? null : () => _setWords(twists: {}),
                      deleteButtonTooltipMessage: 'No twists',
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.add_circle_outline),
                      showCheckmark: false,
                      label: Text(switch (_endings.length) {
                        0 => 'Add ending',
                        1 => 'Ending ${_endings.single.label}',
                        final n => '$n endings',
                      }),
                      tooltip: 'An ending on the last word, like Spotify or Bitly',
                      selected: _endings.isNotEmpty,
                      onSelected: (_) => _pickEndings(),
                      onDeleted: _endings.isEmpty ? null : () => _setWords(endings: {}),
                      deleteButtonTooltipMessage: 'No endings',
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
                        tooltip: _oneWord ? 'One-word names have no word order' : 'Which kind of word goes first',
                        selected: _order != WordOrder.mixed && !_oneWord,
                        onSelected: _oneWord ? null : (_) => menu.isOpen ? menu.close() : menu.open(),
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
                      label: const Text('Same letter'),
                      tooltip: _oneWord
                          ? 'One-word names have only one first letter'
                          : 'Both words start with the same letter, like PayPal',
                      selected: _sameLetter && !_oneWord,
                      onSelected: _oneWord ? null : (on) => _setWords(sameLetter: on),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.edit),
                      showCheckmark: false,
                      label: Text(switch ((_word, _place)) {
                        ('', _) => 'Your own word',
                        (final word, _) when _oneWord => 'With ${_capital(word)}',
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
                  while (index >= _suggestions.length && _names.moveNext()) {
                    _suggestions.add(_names.current);
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
                          subtitle: Text('Try another starting letter, twist, word order or place for your word.'),
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

  Widget _buildRow(Name name) {
    final alreadySaved = _saved.contains(name);
    return _tile(
      name,
      trailing: Icon(
        alreadySaved ? Icons.favorite : Icons.favorite_border,
        color: alreadySaved ? Theme.of(context).colorScheme.primary : null,
        semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
      ),
      onTap: () => setState(() {
        if (!_saved.remove(name)) _saved.add(name);
      }),
    );
  }

  /// A name, with whether its domains are free under it: a sentence for one TLD
  /// ("neatchip.com is free"), a short status per TLD for several.
  ListTile _tile(Name suggested, {Widget? trailing, VoidCallback? onTap}) {
    final name = suggested.asLowerCase;
    return ListTile(
      title: Text(suggested.asPascalCase, style: _biggerFont),
      subtitle: _tlds.length == 1
          ? _domain(name, _tlds.single, brief: false)
          : Wrap(spacing: 14, runSpacing: 2, children: [for (final tld in _tlds) _domain(name, tld, brief: true)]),
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// Whether `name` is free under [tld]: in a sentence, or [brief]ly as the
  /// ending alone, with the sentence as its tooltip. One that couldn't be
  /// checked is asked again when tapped; a taken one shows what its registry
  /// says about it.
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
      Availability.taken => ('$domain is taken: tap for details', colours.outline, Icons.block),
      Availability.unknown => ("Couldn't check $domain: tap to retry", colours.error, Icons.refresh),
    };
    final taken = status == Availability.taken;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: brief ? 15 : 16, color: colour),
        SizedBox(width: brief ? 3 : 6),
        if (brief)
          Text('$tld', style: TextStyle(color: colour))
        else
          Flexible(child: Text(taken ? '$domain is taken' : sentence, style: TextStyle(color: colour))),
        if (taken && !brief) ...[const SizedBox(width: 4), Icon(Icons.info_outline, size: 15, color: colours.primary)],
      ],
    );
    return GestureDetector(
      onTap: switch (status) {
        Availability.unknown => () => widget.checker.retry(name, tld),
        Availability.taken => () => _showRecord(name, tld),
        _ => null,
      },
      child: brief ? Tooltip(message: sentence, child: Semantics(label: sentence, excludeSemantics: true, child: row)) : row,
    );
  }

  void _showRecord(String name, Tld tld) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _RecordSheet(domain: '$name.${tld.name}', record: widget.checker.recordOf(name, tld)),
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

/// What a taken domain's registry says about it, and a link to its site.
class _RecordSheet extends StatelessWidget {
  const _RecordSheet({required this.domain, this.record});

  final String domain;
  final DomainRecord? record;

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
      'October', 'November', 'December'];

  static String _date(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;
    final record = this.record;
    final now = DateTime.now();
    final daysLeft = record?.expires?.difference(now).inDays;
    final market = record?.market;
    final notes = [
      if (record != null && record.beingDeleted)
        'The registry is deleting it, so it may become free soon.'
      else if (daysLeft != null && daysLeft >= 0 && daysLeft <= 60)
        "It expires in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}. If the owner doesn't renew it, it may become free some weeks after that.",
      if (market != null && market.marketplace)
        'Its name servers are with ${market.name}, a domain marketplace, so it is probably for sale there.',
      if (market != null && !market.marketplace)
        'It is parked with ${market.name}, a parking service: the owner may be willing to sell it.',
    ];
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: Text(label, style: TextStyle(color: colours.onSurfaceVariant))),
              Expanded(child: SelectableText(value)),
            ],
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(domain, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Taken', style: TextStyle(color: colours.onSurfaceVariant, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            if (record == null)
              Text("The registry didn't say more about it.", style: TextStyle(color: colours.onSurfaceVariant))
            else ...[
              if (record.registered case final registered?) line('Registered', _date(registered)),
              if (record.expires case final expires?) line('Expires', _date(expires)),
              if (record.registrar case final registrar?) line('Registrar', registrar),
              if (record.nameservers.isNotEmpty) line('Name servers', record.nameservers.join(', ')),
            ],
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Material(
                  color: colours.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(note, style: TextStyle(color: colours.onSecondaryContainer)),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // In a tab of its own, so the list stays as it is.
                Link(
                  uri: Uri.https(domain),
                  target: LinkTarget.blank,
                  builder: (context, open) => FilledButton.icon(
                    onPressed: open,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text('Visit $domain'),
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks some of [options], with a [detail] line under each: answers them in
/// the order of [options], or nothing if cancelled. With [atLeastOne], the last
/// one ticked can't be unticked; with a [noneLabel], a button answers none.
class _PickDialog<T> extends StatefulWidget {
  const _PickDialog({
    required this.title,
    required this.options,
    required this.chosen,
    required this.label,
    required this.detail,
    this.note,
    this.atLeastOne = false,
    this.noneLabel,
  });

  final String title;
  final String? note;
  final List<T> options;
  final Iterable<T> chosen;
  final String Function(T) label;
  final String Function(T) detail;
  final bool atLeastOne;
  final String? noneLabel;

  @override
  State<_PickDialog<T>> createState() => _PickDialogState<T>();
}

class _PickDialogState<T> extends State<_PickDialog<T>> {
  late final _chosen = {...widget.chosen};

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: 340,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (note != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(note, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            for (final option in widget.options)
              CheckboxListTile(
                value: _chosen.contains(option),
                title: Text(widget.label(option)),
                subtitle: Text(widget.detail(option)),
                dense: true,
                // At least one, if asked: there'd be nothing to check.
                onChanged: widget.atLeastOne && _chosen.length == 1 && _chosen.contains(option)
                    ? null
                    : (on) => setState(() => on! ? _chosen.add(option) : _chosen.remove(option)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (widget.noneLabel case final none?) TextButton(onPressed: () => Navigator.pop(context, <T>[]), child: Text(none)),
        FilledButton(
          onPressed: () => Navigator.pop(context, [for (final option in widget.options) if (_chosen.contains(option)) option]),
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
  const _WordDialog({required this.word, required this.place, required this.order, required this.oneWord});

  final String word;
  final Place place;
  final WordOrder order;

  /// Names are one word, so the user's word is all of each, twisted or ended:
  /// there's no place to choose.
  final bool oneWord;

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
          if (widget.oneWord) ...[
            const SizedBox(height: 12),
            Text(
              'Names are one word, so each is your word, twisted or with an ending.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ] else ...[
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
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _use, child: const Text('Use it')),
      ],
    );
  }
}
