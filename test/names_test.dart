import 'dart:math';

import 'package:english_words/english_words.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startup_namer/names.dart';
import 'package:startup_namer/tech_words.dart';

void main() {
  List<WordPair> take({bool longer = false, bool tech = false}) =>
      namePairs(longer: longer, tech: tech, random: Random(7)).take(300).toList();

  test('plain names are two syllables of common words, as the codelab made them', () {
    final names = take();
    expect(names.every((pair) => syllables(pair.join()) <= 2), isTrue);
    expect(names.any((pair) => techWords.contains(pair.first) || techWords.contains(pair.second)), isFalse);
  });

  test('longer words go up to three syllables', () {
    final names = take(longer: true);
    expect(names.every((pair) => syllables(pair.join()) <= 3), isTrue);
    expect(names.where((pair) => syllables(pair.join()) == 3), isNotEmpty);
  });

  test('tech names have one tech word, first or second, and no run-together letters', () {
    for (final names in [take(tech: true), take(tech: true, longer: true)]) {
      for (final pair in names) {
        expect(techWords.contains(pair.first) || techWords.contains(pair.second), isTrue, reason: pair.join());
        expect(pair.first.codeUnits.last == pair.second.codeUnits.first, isFalse, reason: pair.join());
      }
      expect(names.where((pair) => techWords.contains(pair.first)), isNotEmpty);
      expect(names.where((pair) => techWords.contains(pair.second)), isNotEmpty);
    }
  });

  test('no name uses a capitalized word, like Christian or French', () {
    for (final names in [take(), take(longer: true), take(tech: true, longer: true)]) {
      expect(names.where((pair) => pair.join() != pair.join().toLowerCase()), isEmpty);
    }
  });

  test('tech words are lower-case letters, each listed once', () {
    expect(techWords.every((word) => RegExp(r'^[a-z]+$').hasMatch(word)), isTrue);
    expect(techWords.toSet().length, techWords.length);
  });
}
