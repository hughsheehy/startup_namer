import 'dart:math';

import 'package:english_words/english_words.dart';

import 'tech_words.dart';

/// Names made as the original codelab did, from the most used English words: an
/// adjective or noun, then a noun, two syllables in all. `longer` lets in
/// two-syllable words (river, signal), for up to three syllables; `tech` swaps one
/// of the two words for one of [techWords]. Words the list capitalizes are left
/// out: religions, nationalities and people (Christian, French, God, Mrs).
Iterable<WordPair> namePairs({bool longer = false, bool tech = false, Random? random}) sync* {
  final rand = random ?? Random();
  final capital = RegExp('[A-Z]');
  for (final pair in generateWordPairs(maxSyllables: longer ? 3 : 2, random: rand)) {
    if (capital.hasMatch(pair.first) || capital.hasMatch(pair.second)) continue;
    if (!tech) {
      yield pair;
      continue;
    }
    final word = techWords[rand.nextInt(techWords.length)];
    final (first, second) = rand.nextBool() ? (word, pair.second) : (pair.first, word);
    // As the package does, skip words that run into each other ("neonnode").
    if (first == second || first.codeUnits.last == second.codeUnits.first) continue;
    yield WordPair(first, second);
  }
}
