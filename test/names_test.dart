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
    expect(techAdjectives.every(techWords.contains), isTrue);
  });

  List<WordPair> make({
    bool tech = false,
    WordOrder order = WordOrder.mixed,
    String letter = '',
    String word = '',
    Place place = Place.either,
  }) =>
      namePairs(tech: tech, order: order, letter: letter, word: word, place: place, random: Random(7)).take(300).toList();

  test('each word order puts the kinds of word where it says', () {
    final kinds = {
      WordOrder.adjectiveNoun: (adjectives, nouns),
      WordOrder.nounAdjective: (nouns, adjectives),
      WordOrder.nounNoun: (nouns, nouns),
    };
    kinds.forEach((order, lists) {
      final names = make(order: order);
      expect(names, hasLength(300));
      for (final pair in names) {
        expect(lists.$1.contains(pair.first) && lists.$2.contains(pair.second), isTrue, reason: '$order ${pair.join()}');
      }
    });
  });

  test('with tech words, the tech word is of the kind its place asks for', () {
    final names = make(order: WordOrder.nounAdjective, tech: true);
    for (final pair in names) {
      final ok = (techNouns.contains(pair.first) && adjectives.contains(pair.second)) ||
          (nouns.contains(pair.first) && techAdjectives.contains(pair.second));
      expect(ok, isTrue, reason: pair.join());
    }
  });

  test('every name starts with the letter chosen, tech or not', () {
    for (final names in [make(letter: 'q'), make(letter: 'q', tech: true), make(letter: 'Z', order: WordOrder.nounNoun)]) {
      expect(names, isNotEmpty);
      expect(names.every((pair) => pair.first.startsWith(RegExp('[qz]'))), isTrue);
    }
  });

  test("the user's word goes where asked, with the other word tech if asked", () {
    expect(make(word: 'volt', place: Place.first).every((pair) => pair.first == 'volt'), isTrue);
    expect(make(word: 'Volt', place: Place.second).every((pair) => pair.second == 'volt'), isTrue);
    final either = make(word: 'volt');
    expect(either.where((pair) => pair.first == 'volt'), isNotEmpty);
    expect(either.where((pair) => pair.second == 'volt'), isNotEmpty);
    expect(either.every((pair) => pair.first == 'volt' || pair.second == 'volt'), isTrue);
    expect(make(word: 'volt', tech: true).every((pair) => techWords.contains(pair.first) && techWords.contains(pair.second)), isTrue);
    // A long word of the user's own is kept, though it's longer than the others.
    expect(make(word: 'electric', place: Place.first), isNotEmpty);
  });

  test("a letter and the user's word go together where they can", () {
    // Volt can't start a name that starts with Q, so it goes second.
    expect(make(word: 'volt', letter: 'q').every((pair) => pair.first.startsWith('q') && pair.second == 'volt'), isTrue);
    expect(make(word: 'volt', letter: 'v', place: Place.first), isNotEmpty);
  });

  test('options that fit no name give none, and the names run out without repeats', () {
    expect(namePairs(word: 'volt', letter: 'q', place: Place.first), isEmpty);
    final few = namePairs(word: 'volt', place: Place.first, tech: true, order: WordOrder.nounAdjective).toList();
    expect(few, isNotEmpty);
    expect(few.length, lessThanOrEqualTo(techAdjectives.length));
    expect(few.map((pair) => pair.join()).toSet(), hasLength(few.length));
    final many = take(tech: true).map((pair) => pair.join());
    expect(many.toSet(), hasLength(many.length));
  });
}
