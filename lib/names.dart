import 'dart:math';

import 'package:english_words/english_words.dart';
// The package keeps to itself its list of words (and joins) to leave out, the one
// its own generator uses, and its one-syllable safe words, worked out ahead.
// ignore: implementation_imports
import 'package:english_words/src/words/adjectives_monosyllabic_safe.dart';
// ignore: implementation_imports
import 'package:english_words/src/words/nouns_monosyllabic_safe.dart';
// ignore: implementation_imports
import 'package:english_words/src/words/unsafe.dart';

import 'more_words.dart';
import 'spelling.dart';
import 'tech_words.dart';

/// Which kind of word goes first and which second, with a word of each kind for
/// examples.
enum WordOrder {
  mixed('Mixed order', 'Bright', 'River'),
  adjectiveNoun('Adjective + noun', 'Bright', 'River'),
  nounAdjective('Noun + adjective', 'River', 'Bright'),
  nounNoun('Noun + noun', 'Stone', 'River');

  const WordOrder(this.label, this.first, this.second);

  final String label;
  final String first;
  final String second;

  /// Names this order makes, like "BrightRiver".
  String get example => this == mixed ? 'BrightRiver or StoneRiver' : '$first$second';
}

/// Where the user's own word goes in each name.
enum Place {
  first('First'),
  second('Second'),
  either('Either');

  const Place(this.label);

  final String label;
}

/// A name the app suggests: one word, or two run together (BoldBond).
class Name {
  Name(this.words, {this.spoken}) : assert(words.isNotEmpty && words.every((word) => word.isNotEmpty));

  /// Lower-case but for a Hub ending, which keeps its capital (sparkHub).
  final List<String> words;

  /// For a twisted name, its words spelled the usual way, as people who hear
  /// it would type it: wise owl for WyseOwl. Null for any other name.
  final List<String>? spoken;

  /// The usual spelling's domain name, for a twisted name: wiseowl.
  String? get spokenLowerCase => spoken?.join().toLowerCase();

  String get first => words.first;
  String get last => words.last;

  /// As its domain has it: boldbond, sparkhub.
  String get asLowerCase => words.join().toLowerCase();

  /// As it shows: BoldBond, SparkHub, Tumblr.
  String get asPascalCase => [for (final word in words) word[0].toUpperCase() + word.substring(1)].join();

  @override
  bool operator ==(Object other) => other is Name && other.asPascalCase == asPascalCase;

  @override
  int get hashCode => asPascalCase.hashCode;

  @override
  String toString() => asPascalCase;
}

enum _Kind { adjective, noun, either }

/// One way of making a name: for each of its words, the lists to pick that word
/// from (one list at random, then a word from it), and whether all its words
/// are plain English words.
///
/// [twisted] is which word, if any, is twisted.
typedef _Way = ({List<List<List<String>>> words, bool plain, int? twisted});

/// Where a word of a name comes from: its lists, given the most syllables its
/// words may have (which only plain words heed).
typedef _Slot = List<List<String>> Function(int syllables);

/// Names made as the original codelab did, from the most used English words.
///
/// By default, an adjective or noun then a noun, two syllables in all; [order]
/// picks the kinds of word instead. [oneWord] makes names of a single word, an
/// adjective or a noun of up to two syllables, best with a twist or an ending.
/// [more] adds 2,000 more adjectives and 4,700 more nouns, less common ones too
/// (tundra, velocity, celestial), from [extraAdjectives] and [extraNouns].
/// [longer] lets in words a syllable longer (river, signal). [tech] makes one
/// of the two words one of [techWords], or the one word a tech word. [letter]
/// is the letter every name starts with, and [word] a word of the user's own
/// that's in every name, in the [place] asked for; with [tech] as well, the
/// other word is the tech word. [sameLetter] makes the second word start as the
/// first does (PayPal).
///
/// With [twists], one word of every name is spelled differently by one of
/// them (Tumblr, Lyft); with [endings], the last word of every name has one of
/// them (Spotify). With both, each name has one or the other. [letter] goes by
/// the name as twisted: kool starts with k.
///
/// Each name comes once. If nothing fits (no adjective starts with x, say), or
/// every name that does has been given, the names run out.
///
/// Words the list capitalizes are left out: religions, nationalities and people
/// (Christian, French, God, Mrs).
Iterable<Name> suggestNames({
  bool longer = false,
  bool more = false,
  bool tech = false,
  bool oneWord = false,
  WordOrder order = WordOrder.mixed,
  String letter = '',
  String word = '',
  Place place = Place.either,
  Set<Twist> twists = const {},
  Set<Ending> endings = const {},
  bool sameLetter = false,
  Random? random,
}) sync* {
  final rand = random ?? Random();
  letter = letter.toLowerCase();
  word = word.toLowerCase();
  final maxPerWord = longer ? 2 : 1;
  // One word may be as long as two would have been together.
  final maxSyllables = oneWord ? maxPerWord + 1 : maxPerWord;
  final (firstKind, secondKind) = switch (order) {
    _ when oneWord => (_Kind.either, _Kind.either),
    WordOrder.mixed => (_Kind.either, _Kind.noun),
    WordOrder.adjectiveNoun => (_Kind.adjective, _Kind.noun),
    WordOrder.nounAdjective => (_Kind.noun, _Kind.adjective),
    WordOrder.nounNoun => (_Kind.noun, _Kind.noun),
  };

  // An "either" slot is half adjectives and half nouns, as the codelab had it.
  _Slot plain(_Kind kind) => (syllables) => [
        if (kind != _Kind.noun) _words(more ? _allAdjectives : adjectives, syllables),
        if (kind != _Kind.adjective) _words(more ? _allNouns : nouns, syllables),
      ];
  _Slot techy(_Kind kind) => (_) => [
        switch (kind) {
          _Kind.adjective => techAdjectives,
          _Kind.noun => techNouns,
          _Kind.either => techWords,
        },
      ];
  List<List<String>> mine(int _) => [
        [word],
      ];
  _Slot other(_Kind kind) => tech ? techy(kind) : plain(kind);

  // Plain words, or a tech word in either place, or the user's word in the place
  // asked (and the other word plain or tech). One word is the user's, or else
  // plain or tech.
  final shapes = <({List<_Slot> words, bool plain})>[
    if (oneWord) (words: [word.isNotEmpty ? mine : other(_Kind.either)], plain: word.isEmpty && !tech),
    if (!oneWord && word.isEmpty && !tech) (words: [plain(firstKind), plain(secondKind)], plain: true),
    if (!oneWord && word.isEmpty && tech) ...[
      (words: [techy(firstKind), plain(secondKind)], plain: false),
      (words: [plain(firstKind), techy(secondKind)], plain: false),
    ],
    if (!oneWord && word.isNotEmpty && place != Place.second) (words: [mine, other(secondKind)], plain: false),
    if (!oneWord && word.isNotEmpty && place != Place.first) (words: [other(firstKind), mine], plain: false),
  ];

  // With twists, any one word twisted, and it may be a syllable longer: most
  // twists suit one-syllable words, but dropping a vowel suits two (tumbler),
  // and makes them read shorter. With endings, the last word ended, and kept
  // short, as the names that do it are (Spotify, Bitly).
  final styled = <_Way>[
    for (final shape in shapes) ...[
      if (twists.isEmpty && endings.isEmpty) (words: [for (final slot in shape.words) slot(maxSyllables)], plain: shape.plain, twisted: null),
      if (twists.isNotEmpty)
        for (var i = 0; i < shape.words.length; i++)
          (
            words: [
              for (var j = 0; j < shape.words.length; j++)
                j == i ? _twisted(shape.words[j](maxPerWord + 1), twists) : shape.words[j](maxSyllables),
            ],
            plain: false,
            twisted: i,
          ),
      if (endings.isNotEmpty)
        (
          words: [
            for (final slot in shape.words.sublist(0, shape.words.length - 1)) slot(maxSyllables),
            _ended(shape.words.last(maxPerWord), endings),
          ],
          plain: false,
          twisted: null,
        ),
    ],
  ];

  // The first word is the one that has to start with the letter. Lists left
  // empty go, and ways with a word that has none.
  final ways = [
    for (final way in styled)
      (
        words: [
          for (var i = 0; i < way.words.length; i++)
            [
              for (final list in way.words[i])
                if ((i == 0 ? _startingWith(list, letter) : list) case final kept when kept.isNotEmpty) kept,
            ],
        ],
        plain: way.plain,
        twisted: way.twisted,
      ),
  ].where((way) => way.words.every((lists) => lists.isNotEmpty)).toList();
  if (ways.isEmpty) return;

  String pick(List<List<String>> lists) {
    final list = lists[rand.nextInt(lists.length)];
    return list[rand.nextInt(list.length)];
  }

  final given = <String>{};
  const giveUpAfter = 2000; // Tries in a row without a new name.
  for (var misses = 0; misses < giveUpAfter; misses++) {
    final way = ways[rand.nextInt(ways.length)];
    final first = pick(way.words.first);
    final words = [first];
    if (way.words.length == 2) {
      var lists = way.words.last;
      if (sameLetter) {
        lists = [
          for (final list in lists)
            if (_startingWith(list, first[0]) case final kept when kept.isNotEmpty) kept,
        ];
        if (lists.isEmpty) continue;
      }
      final second = pick(lists);
      // As the package does, skip words that run into each other ("neonnode").
      if (first == second.toLowerCase() || first.codeUnits.last == second.toLowerCase().codeUnits.first) continue;
      words.add(second);
    }
    final name = words.join().toLowerCase();
    if (_unsafePairs.contains(name)) continue;
    // And two plain words that sound longer together than apart ("timetime").
    if (way.plain && words.length == 2 && syllables(name) > maxPerWord + 1) continue;
    if (!given.add(name)) continue;
    misses = -1;
    final twisted = way.twisted;
    yield Name(
      words,
      spoken: twisted == null ? null : [for (final (i, word) in words.indexed) i == twisted ? _untwisted[word] ?? word : word],
    );
  }
}

final _unsafe = unsafe.toSet();
final _unsafePairs = unsafePairs.toSet();
final _wordLists = <(List<String>, int), List<String>>{};
final _styledLists = <(List<String>, Object), List<String>>{};
final _byLetter = <(List<String>, String), List<String>>{};

/// Every word the app has, plain: a twist or an ending that makes one of them
/// (night to nite, lob to lobster) isn't a twist.
final _plainWords = {...adjectives, ...nouns, ...extraAdjectives, ...extraNouns, ...techWords};

/// Each twisted word, and the word it was twisted from: wyse, wise.
final _untwisted = <String, String>{};

/// Each word of `lists` spelled by each of `twists` that suits it.
List<List<String>> _twisted(List<List<String>> lists, Set<Twist> twists) => [
      for (final list in lists)
        _styled(list, (Twist.values.where(twists.contains).toList(), 'twist'), (word) {
          final spelled = [for (final twist in Twist.values) if (twists.contains(twist)) twist.apply(word)];
          for (final twisted in spelled.nonNulls) {
            _untwisted.putIfAbsent(twisted, () => word);
          }
          return spelled;
        }),
    ];

/// Each word of `lists` with each of `endings` that suits it.
List<List<String>> _ended(List<List<String>> lists, Set<Ending> endings) => [
      for (final list in lists)
        _styled(list, (Ending.values.where(endings.contains).toList(), 'ending'),
            (word) => [for (final ending in Ending.values) if (endings.contains(ending)) ending.apply(word)]),
    ];

/// The new spellings `style` gives the words of `list`, but none that is a plain
/// word or unsafe, worked out once for each list and style. (A user's own word
/// is a list of its own each time, so it isn't kept.)
List<String> _styled(List<String> list, (List<Object>, String) key, List<String?> Function(String) style) {
  List<String> make() => {
        for (final word in list)
          for (final styled in style(word))
            if (styled != null && !_plainWords.contains(styled.toLowerCase()) && !_unsafe.contains(styled.toLowerCase()))
              styled,
      }.toList();
  if (list.length < 50) return make();
  return _styledLists.putIfAbsent((list, '${key.$2}:${key.$1.join(',')}'), make);
}

/// The lower-case, safe words of `list` of up to `maxSyllables`, worked out once.
/// The words with "More words" on: english_words' and the extra ones.
final _allAdjectives = [...adjectives, ...extraAdjectives];
final _allNouns = [...nouns, ...extraNouns];

List<String> _words(List<String> list, int maxSyllables) => _wordLists.putIfAbsent(
      (list, maxSyllables),
      () => switch ((list, maxSyllables)) {
        // The default: the package's own one-syllable lists, so the app doesn't
        // count syllables for 3,000 words as it starts.
        (adjectives, 1) => [for (final word in adjectivesMonosyllabicSafe) if (_lowerCase.hasMatch(word)) word],
        (nouns, 1) => [for (final word in nounsMonosyllabicSafe) if (_lowerCase.hasMatch(word)) word],
        _ => _counted(list, maxSyllables),
      },
    );

final _lowerCase = RegExp(r'^[a-z]+$');

/// The lower-case, safe words of `list` of up to `maxSyllables`, counted.
List<String> _counted(List<String> list, int maxSyllables) => [
      for (final word in list)
        if (_lowerCase.hasMatch(word) && !_unsafe.contains(word) && syllablesOf(word) <= maxSyllables) word,
    ];

/// The words of `list` that start with `letter`: all of them for ''. Kept for
/// the long lists, which the same-letter option asks again and again.
List<String> _startingWith(List<String> list, String letter) {
  if (letter.isEmpty) return list;
  List<String> make() => [for (final word in list) if (word.startsWith(letter)) word];
  return list.length < 50 ? make() : _byLetter.putIfAbsent((list, letter), make);
}
