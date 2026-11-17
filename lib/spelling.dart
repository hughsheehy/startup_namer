import 'package:english_words/english_words.dart';

/// A way of spelling a word differently, as startups do to find a name that's
/// free: Tumblr, Lyft, Digg.
///
/// Each one changes only words it reads well on, and gives null for the rest.
/// Long words look silly twisted, and some patterns read wrongly once changed
/// (weight is not "weite", circle not "cyrcle"), so those are left alone.
enum Twist {
  dropVowel('Drop a vowel', 'Tumblr', 'paper → papr, bundle → bundl'),
  iToY('i to y', 'Lyft', 'wise → wyse, lift → lyft'),
  ightToIte('-ight to -ite', 'Lite', 'bright → brite'),
  cToK('c to k', 'Kwik', 'cool → kool, quick → kwik'),
  doubleLast('Double the last letter', 'Digg', 'dig → digg');

  const Twist(this.label, this.brand, this.example);

  final String label;

  /// A company spelled this way.
  final String brand;
  final String example;

  /// `word` spelled this way, or null if this twist doesn't suit it.
  String? apply(String word) {
    final twisted = switch (this) {
      dropVowel => _dropVowel(word),
      iToY => _iToY(word),
      ightToIte => _ightToIte(word),
      cToK => _cToK(word),
      doubleLast => _doubleLast(word),
    };
    return twisted == word ? null : twisted;
  }
}

/// An ending put on a word to make a name of it: Spotify, Bitly, Napster.
enum Ending {
  ly('-ly', 'Bitly'),
  ify('-ify', 'Spotify'),
  io('-io', 'Twilio'),
  ster('-ster', 'Napster'),
  sy('-sy', 'Etsy'),
  hub('-hub', 'GitHub');

  const Ending(this.label, this.brand);

  final String label;

  /// A company named this way.
  final String brand;

  /// `word` with this ending, or null if it doesn't suit it. Hub keeps its
  /// capital, as in GitHub, so the name shows as SparkHub.
  String? apply(String word) {
    // Not on -ed words either (nakedHub, driedsy).
    if (word.length < 3 || syllablesOf(word) > 2 || (word.length > 4 && word.endsWith('ed'))) return null;
    final last = word[word.length - 1];
    final consonantLast = !_vowels.contains(last) && last != 'y';
    final consonantBefore = !'aeiouy'.contains(word[word.length - 2]);
    final ending = this == ify ? 'ify' : 'io';
    return switch (this) {
      // Not "simplely", "happyly" or "coolly".
      ly => consonantLast && !word.endsWith('l') ? '${word}ly' : null,
      // Shape → shapify, candy → candify; not after other vowels (radioify,
      // honeify), or after h, s, w or x (thighio, oddsify, toughify).
      ify || io => switch (last) {
          'e' || 'y' when consonantBefore => '${word.substring(0, word.length - 1)}$ending',
          _ when consonantLast && !'hwxs'.contains(last) => '$word$ending',
          _ => null,
        },
      // Not "justster" or "flashster".
      ster => consonantLast && !'sxzh'.contains(last) && !word.endsWith('st') ? '${word}ster' : null,
      // Only after one consonant that follows a vowel, as in Etsy: not
      // "standsy".
      sy => consonantLast && !'sxzhcrw'.contains(last) && !consonantBefore ? '${word}sy' : null,
      hub => last != 'h' ? '${word}Hub' : null,
    };
  }
}

const _vowels = 'aeiou';

final _syllables = <String, int>{};

/// How many syllables english_words counts in `word`, counted once.
int syllablesOf(String word) => _syllables.putIfAbsent(word, () => syllables(word));

/// Tumbler → tumblr, vector → vectr, bundle → bundl: the e of an -er, -tor or
/// -le ending goes, after a consonant that still reads the same. Not after c
/// (dancer would read "dank-r"), not in words over seven letters (researchr),
/// and only where a vowel is left before it.
String _dropVowel(String word) {
  if (word.length < 5 || word.length > 7) return word;
  final stem = word.substring(0, word.length - 2);
  if (!RegExp('[aeiouy]').hasMatch(stem.substring(0, stem.length - 1))) return word;
  final before = stem[stem.length - 1];
  if (word.endsWith('er') && !'aeiouwyrc'.contains(before)) return '${stem}r';
  if (word.endsWith('tor')) return '${word.substring(0, word.length - 2)}r';
  if (word.endsWith('le') && !'aeiouwyl'.contains(before)) return word.substring(0, word.length - 1);
  return word;
}

/// Wise → wyse, lift → lyft: the i of a one-syllable word of four letters or
/// more, where it's the only vowel. Not where it says something else (bright,
/// thirst), before a doubled letter, ck, dge or tch, or three consonants
/// (bill, stick, bridge, switch, midst), or at the start (ink).
String _iToY(String word) {
  if (word.length < 4 || syllablesOf(word) != 1) return word;
  final i = word.indexOf('i');
  if (i <= 0 || i != word.lastIndexOf('i')) return word;
  // The only vowel, save a silent e at the end (wise, fire, time).
  final rest = word.substring(0, i) + word.substring(i + 1);
  final withoutE = rest.endsWith('e') ? rest.substring(0, rest.length - 1) : rest;
  if (RegExp('[aeiouy]').hasMatch(withoutE)) return word;
  final after = word.substring(i + 1);
  if (RegExp(r'^(gh|ck|dge|tch|r(?!e$)|[^aeiou]{3})').hasMatch(after)) return word;
  if (after.length >= 2 && after[0] == after[1]) return word;
  return '${word.substring(0, i)}y$after';
}

/// Bright → brite, nightfall → nitefall. Not eight or height, which say it
/// another way, nor before a vowel (fighter, mighty).
String _ightToIte(String word) => word.replaceAll(RegExp('(?<![aeiou])ight(?![aeiouy])'), 'ite');

/// Cool → kool, quick → kwik, epic → epik: a hard c at the start or the end
/// becomes k, as does qu at the start. Not in long words (komfortable, klothing),
/// nor before a doubled letter (komment, kotton).
String _cToK(String word) {
  if (word.length > 7 || syllablesOf(word) > 2) return word;
  if (RegExp(r'^c[aeiou]([^aeiou])\1').hasMatch(word)) return word;
  return word
      .replaceFirst(RegExp('^qu(?=[aeiou])'), 'kw')
      .replaceFirst(RegExp('^c(?=[aoulr])'), 'k')
      .replaceFirst(RegExp(r'ck$'), 'k')
      .replaceFirst(RegExp(r'(?<=[^aeiou]i)c$'), 'k');
}

/// Dig → digg, star → starr: the last letter of a short one-syllable word,
/// after a single vowel. Not two-syllable words (iron would read "ironn"), nor
/// -ed (armedd).
String _doubleLast(String word) {
  if (word.length < 3 || word.length > 5 || syllablesOf(word) != 1 || word.endsWith('ed')) return word;
  final n = word.length;
  final last = word[n - 1], vowel = word[n - 2], before = word[n - 3];
  if (!'bdgnprt'.contains(last) || !_vowels.contains(vowel) || _vowels.contains(before)) return word;
  return '$word$last';
}
