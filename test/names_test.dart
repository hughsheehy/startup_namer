import 'dart:math';

import 'package:english_words/english_words.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startup_namer/more_words.dart';
import 'package:startup_namer/names.dart';
import 'package:startup_namer/spelling.dart';
import 'package:startup_namer/tech_words.dart';

void main() {
  List<Name> take({bool longer = false, bool tech = false}) =>
      suggestNames(longer: longer, tech: tech, random: Random(7)).take(300).toList();

  test('plain names are two syllables of common words, as the codelab made them', () {
    final names = take();
    expect(names.every((pair) => syllables(pair.asLowerCase) <= 2), isTrue);
    expect(names.any((pair) => techWords.contains(pair.first) || techWords.contains(pair.last)), isFalse);
  });

  test('longer words go up to three syllables', () {
    final names = take(longer: true);
    expect(names.every((pair) => syllables(pair.asLowerCase) <= 3), isTrue);
    expect(names.where((pair) => syllables(pair.asLowerCase) == 3), isNotEmpty);
  });

  test('tech names have one tech word, first or second, and no run-together letters', () {
    for (final names in [take(tech: true), take(tech: true, longer: true)]) {
      for (final pair in names) {
        expect(techWords.contains(pair.first) || techWords.contains(pair.last), isTrue, reason: pair.asLowerCase);
        expect(pair.first.codeUnits.last == pair.last.codeUnits.first, isFalse, reason: pair.asLowerCase);
      }
      expect(names.where((pair) => techWords.contains(pair.first)), isNotEmpty);
      expect(names.where((pair) => techWords.contains(pair.last)), isNotEmpty);
    }
  });

  test('no name uses a capitalized word, like Christian or French', () {
    for (final names in [take(), take(longer: true), take(tech: true, longer: true)]) {
      expect(names.where((pair) => pair.asLowerCase != pair.asLowerCase.toLowerCase()), isEmpty);
    }
  });

  test('tech words are lower-case letters, each listed once', () {
    expect(techWords.every((word) => RegExp(r'^[a-z]+$').hasMatch(word)), isTrue);
    expect(techWords.toSet().length, techWords.length);
    expect(techAdjectives.every(techWords.contains), isTrue);
  });

  List<Name> make({
    bool tech = false,
    WordOrder order = WordOrder.mixed,
    String letter = '',
    String word = '',
    Place place = Place.either,
  }) =>
      suggestNames(tech: tech, order: order, letter: letter, word: word, place: place, random: Random(7)).take(300).toList();

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
        expect(lists.$1.contains(pair.first) && lists.$2.contains(pair.last), isTrue, reason: '$order ${pair.asLowerCase}');
      }
    });
  });

  test('with tech words, the tech word is of the kind its place asks for', () {
    final names = make(order: WordOrder.nounAdjective, tech: true);
    for (final pair in names) {
      final ok = (techNouns.contains(pair.first) && adjectives.contains(pair.last)) ||
          (nouns.contains(pair.first) && techAdjectives.contains(pair.last));
      expect(ok, isTrue, reason: pair.asLowerCase);
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
    expect(make(word: 'Volt', place: Place.second).every((pair) => pair.last == 'volt'), isTrue);
    final either = make(word: 'volt');
    expect(either.where((pair) => pair.first == 'volt'), isNotEmpty);
    expect(either.where((pair) => pair.last == 'volt'), isNotEmpty);
    expect(either.every((pair) => pair.first == 'volt' || pair.last == 'volt'), isTrue);
    expect(make(word: 'volt', tech: true).every((pair) => techWords.contains(pair.first) && techWords.contains(pair.last)), isTrue);
    // A long word of the user's own is kept, though it's longer than the others.
    expect(make(word: 'electric', place: Place.first), isNotEmpty);
  });

  test("a letter and the user's word go together where they can", () {
    // Volt can't start a name that starts with Q, so it goes second.
    expect(make(word: 'volt', letter: 'q').every((pair) => pair.first.startsWith('q') && pair.last == 'volt'), isTrue);
    expect(make(word: 'volt', letter: 'v', place: Place.first), isNotEmpty);
  });

  test('options that fit no name give none, and the names run out without repeats', () {
    expect(suggestNames(word: 'volt', letter: 'q', place: Place.first), isEmpty);
    final few = suggestNames(word: 'volt', place: Place.first, tech: true, order: WordOrder.nounAdjective).toList();
    expect(few, isNotEmpty);
    expect(few.length, lessThanOrEqualTo(techAdjectives.length));
    expect(few.map((pair) => pair.asLowerCase).toSet(), hasLength(few.length));
    final many = take(tech: true).map((pair) => pair.asLowerCase);
    expect(many.toSet(), hasLength(many.length));
  });

  test('more words adds less common words, all lower-case, none repeated or from english_words', () {
    final all = {...adjectives, ...nouns};
    expect(extraAdjectives.toSet(), hasLength(extraAdjectives.length));
    expect(extraNouns.toSet(), hasLength(extraNouns.length));
    for (final word in [...extraAdjectives, ...extraNouns]) {
      expect(RegExp(r'^[a-z]{3,14}$').hasMatch(word), isTrue, reason: word);
      expect(all.contains(word), isFalse, reason: word);
    }
    expect(extraAdjectives.length, greaterThan(1500));
    expect(extraNouns.length, greaterThan(4000));
  });

  test('more words draws on the extra words too, still keeping each word order', () {
    final names = suggestNames(more: true, longer: true, order: WordOrder.adjectiveNoun, random: Random(7)).take(400).toList();
    expect(names, hasLength(400));
    final extra = {...extraAdjectives, ...extraNouns};
    expect(names.where((pair) => extra.contains(pair.first) || extra.contains(pair.last)), isNotEmpty);
    for (final pair in names) {
      expect((adjectives.contains(pair.first) || extraAdjectives.contains(pair.first)) &&
          (nouns.contains(pair.last) || extraNouns.contains(pair.last)), isTrue, reason: pair.asLowerCase);
    }
    // Without it, none of the extra words.
    final plain = suggestNames(longer: true, random: Random(7)).take(400);
    expect(plain.where((pair) => extra.contains(pair.first) || extra.contains(pair.last)), isEmpty);
  });

  final plainWords = {...adjectives, ...nouns, ...extraAdjectives, ...extraNouns, ...techWords};
  bool isPlain(String word) => plainWords.contains(word.toLowerCase());

  List<Name> styled({
    bool oneWord = false,
    bool longer = false,
    Set<Twist> twists = const {},
    Set<Ending> endings = const {},
    bool sameLetter = false,
    String letter = '',
    String word = '',
    bool tech = false,
  }) =>
      suggestNames(
        oneWord: oneWord,
        longer: longer,
        twists: twists,
        endings: endings,
        sameLetter: sameLetter,
        letter: letter,
        word: word,
        tech: tech,
        random: Random(7),
      ).take(300).toList();

  test('a name shows each word with a capital, and its domain in lower case', () {
    expect(Name(['bold', 'sparkHub']).asPascalCase, 'BoldSparkHub');
    expect(Name(['bold', 'sparkHub']).asLowerCase, 'boldsparkhub');
    expect(Name(['tumblr']).asPascalCase, 'Tumblr');
    expect(Name(['bold', 'bond']), Name(['bold', 'bond']));
  });

  test('one-word names are one plain word, up to two syllables, or three with longer words', () {
    final names = styled(oneWord: true);
    expect(names, hasLength(300));
    for (final name in names) {
      expect(name.words, hasLength(1));
      expect(isPlain(name.first), isTrue, reason: '$name');
      expect(syllables(name.first), lessThanOrEqualTo(2), reason: '$name');
    }
    expect(styled(oneWord: true).where((name) => syllables(name.first) == 2), isNotEmpty);
    expect(styled(oneWord: true, longer: true).where((name) => syllables(name.first) == 3), isNotEmpty);
  });

  test('with twists, one word of every name is twisted', () {
    for (final names in [styled(twists: Twist.values.toSet()), styled(twists: {Twist.cToK}, tech: true)]) {
      expect(names, hasLength(300));
      for (final name in names) {
        expect(name.words.where((word) => !isPlain(word)), hasLength(1), reason: '$name');
      }
    }
    final wyse = styled(oneWord: true, twists: {Twist.iToY});
    expect(wyse, isNotEmpty);
    expect(wyse.every((name) => name.first.contains('y') && !isPlain(name.first)), isTrue);
    // Every twist makes names of one word, and some of two.
    for (final twist in Twist.values) {
      expect(styled(oneWord: true, twists: {twist}).length, greaterThan(5), reason: '$twist');
      expect(styled(twists: {twist}), isNotEmpty, reason: '$twist');
    }
  });

  test('with endings, the last word of every name has one', () {
    final ify = styled(oneWord: true, endings: {Ending.ify});
    expect(ify, hasLength(300));
    expect(ify.every((name) => name.first.endsWith('ify')), isTrue);
    final hub = styled(endings: {Ending.hub});
    expect(hub.every((name) => name.words.length == 2 && name.asPascalCase.endsWith('Hub')), isTrue);
    // With twists too, each name has one or the other.
    final both = styled(oneWord: true, twists: {Twist.iToY}, endings: {Ending.ly});
    expect(both.where((name) => name.first.endsWith('ly')), isNotEmpty);
    expect(both.where((name) => !name.first.endsWith('ly') && name.first.contains('y')), isNotEmpty);
  });

  test("the user's own word, as one word, comes twisted or ended", () {
    final volt = suggestNames(oneWord: true, word: 'volt', endings: {Ending.ify, Ending.ly}).map((name) => '$name');
    expect(volt.toSet(), {'Voltify', 'Voltly'});
    expect(suggestNames(oneWord: true, word: 'volt', twists: {Twist.iToY}), isEmpty);
    // In two words, the other word takes the twist when the user's word can't.
    final twoWords = styled(word: 'volt', twists: {Twist.iToY});
    expect(twoWords, isNotEmpty);
    expect(twoWords.every((name) => name.words.contains('volt') && name.asLowerCase.contains('y')), isTrue);
  });

  test('the starting letter goes by the twisted spelling', () {
    final names = styled(oneWord: true, letter: 'k', twists: {Twist.cToK});
    expect(names, isNotEmpty);
    expect(names.every((name) => name.first.startsWith('k') && !isPlain(name.first)), isTrue);
  });

  test('with the same first letter, both words start alike', () {
    for (final names in [styled(sameLetter: true), styled(sameLetter: true, letter: 'b'), styled(sameLetter: true, tech: true)]) {
      expect(names, hasLength(300));
      expect(names.every((name) => name.first[0] == name.last[0]), isTrue);
    }
    expect(styled(sameLetter: true, letter: 'b').every((name) => name.first.startsWith('b')), isTrue);
    expect(styled(sameLetter: true, word: 'volt').every((name) => name.asLowerCase.startsWith('v')), isTrue);
  });

  test('a twisted name keeps its usual spelling; other names have none', () {
    for (final name in styled(oneWord: true, twists: {Twist.iToY})) {
      expect(Twist.iToY.apply(name.spoken!.single), name.first, reason: '$name');
    }
    for (final name in styled(twists: Twist.values.toSet())) {
      final spoken = name.spoken!;
      expect(spoken, hasLength(2));
      final changed = [for (var i = 0; i < 2; i++) if (spoken[i] != name.words[i]) i];
      expect(changed, hasLength(1), reason: '$name $spoken');
      expect(isPlain(spoken[changed.single]), isTrue, reason: '$name $spoken');
    }
    expect(styled(word: 'link', twists: {Twist.iToY}).where((name) => name.spokenLowerCase!.contains('link')), isNotEmpty);
    expect(styled(oneWord: true, endings: {Ending.ify}).every((name) => name.spoken == null), isTrue);
    expect(styled().every((name) => name.spoken == null), isTrue);
  });
}
