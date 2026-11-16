import 'dart:math';

import 'package:english_words/english_words.dart';
// The package keeps to itself its list of words (and joins) to leave out, the one
// its own generator uses.
// ignore: implementation_imports
import 'package:english_words/src/words/unsafe.dart';

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

enum _Kind { adjective, noun, either }

/// One way of making a name: the lists to pick its first word from and those for
/// its second (one list at random, then a word from it), and whether both words
/// are plain English words.
typedef _Way = ({List<List<String>> first, List<List<String>> second, bool plain});

/// Names made as the original codelab did, from the most used English words.
///
/// By default, an adjective or noun then a noun, two syllables in all; [order]
/// picks the kinds of word instead. [longer] lets in two-syllable words (river,
/// signal), for up to three syllables. [tech] makes one of the two words one of
/// [techWords]. [letter] is the letter every name starts with, and [word] a word
/// of the user's own that's in every name, in the [place] asked for; with [tech]
/// as well, the other word is the tech word. Each name comes once. If nothing
/// fits (no adjective starts with x, say), or every name that does has been
/// given, the names run out.
///
/// Words the list capitalizes are left out: religions, nationalities and people
/// (Christian, French, God, Mrs).
Iterable<WordPair> namePairs({
  bool longer = false,
  bool tech = false,
  WordOrder order = WordOrder.mixed,
  String letter = '',
  String word = '',
  Place place = Place.either,
  Random? random,
}) sync* {
  final rand = random ?? Random();
  letter = letter.toLowerCase();
  word = word.toLowerCase();
  final maxPerWord = longer ? 2 : 1;
  final (firstKind, secondKind) = switch (order) {
    WordOrder.mixed => (_Kind.either, _Kind.noun),
    WordOrder.adjectiveNoun => (_Kind.adjective, _Kind.noun),
    WordOrder.nounAdjective => (_Kind.noun, _Kind.adjective),
    WordOrder.nounNoun => (_Kind.noun, _Kind.noun),
  };

  // An "either" slot is half adjectives and half nouns, as the codelab had it. The
  // first word is the one that has to start with the letter.
  List<List<String>> only(List<List<String>> lists, bool first) =>
      [for (final list in lists) first ? _startingWith(list, letter) : list].where((l) => l.isNotEmpty).toList();
  List<List<String>> plain(_Kind kind, {bool first = false}) => only([
        if (kind != _Kind.noun) _words(adjectives, maxPerWord),
        if (kind != _Kind.adjective) _words(nouns, maxPerWord),
      ], first);
  List<List<String>> techy(_Kind kind, {bool first = false}) => only([
        switch (kind) {
          _Kind.adjective => techAdjectives,
          _Kind.noun => techNouns,
          _Kind.either => techWords,
        },
      ], first);
  List<List<String>> mine({bool first = false}) => only([[word]], first);
  List<List<String>> other(_Kind kind, {bool first = false}) =>
      tech ? techy(kind, first: first) : plain(kind, first: first);

  // Plain words, or a tech word in either place, or the user's word in the place
  // asked (and the other word plain or tech).
  final ways = <_Way>[
    if (word.isEmpty && !tech) (first: plain(firstKind, first: true), second: plain(secondKind), plain: true),
    if (word.isEmpty && tech) ...[
      (first: techy(firstKind, first: true), second: plain(secondKind), plain: false),
      (first: plain(firstKind, first: true), second: techy(secondKind), plain: false),
    ],
    if (word.isNotEmpty && place != Place.second) (first: mine(first: true), second: other(secondKind), plain: false),
    if (word.isNotEmpty && place != Place.first) (first: other(firstKind, first: true), second: mine(), plain: false),
  ].where((way) => way.first.isNotEmpty && way.second.isNotEmpty).toList();
  if (ways.isEmpty) return;

  String pick(List<List<String>> lists) {
    final list = lists[rand.nextInt(lists.length)];
    return list[rand.nextInt(list.length)];
  }

  final given = <String>{};
  const giveUpAfter = 2000; // Tries in a row without a new name.
  for (var misses = 0; misses < giveUpAfter; misses++) {
    final way = ways[rand.nextInt(ways.length)];
    final first = pick(way.first), second = pick(way.second);
    final name = '$first$second';
    // As the package does, skip words that run into each other ("neonnode"), and
    // two plain words that sound longer together than apart ("timetime").
    if (first == second || first.codeUnits.last == second.codeUnits.first) continue;
    if (_unsafePairs.contains(name)) continue;
    if (way.plain && syllables(name) > maxPerWord + 1) continue;
    if (!given.add(name)) continue;
    misses = -1;
    yield WordPair(first, second);
  }
}

final _unsafe = unsafe.toSet();
final _unsafePairs = unsafePairs.toSet();
final _wordLists = <(List<String>, int), List<String>>{};

/// The lower-case, safe words of `list` of up to `maxSyllables`, worked out once.
List<String> _words(List<String> list, int maxSyllables) => _wordLists.putIfAbsent(
      (list, maxSyllables),
      () => [
        for (final word in list)
          if (RegExp(r'^[a-z]+$').hasMatch(word) && !_unsafe.contains(word) && syllables(word) <= maxSyllables) word,
      ],
    );

List<String> _startingWith(List<String> list, String letter) =>
    letter.isEmpty ? list : [for (final word in list) if (word.startsWith(letter)) word];
