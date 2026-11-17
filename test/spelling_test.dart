import 'package:flutter_test/flutter_test.dart';
import 'package:startup_namer/spelling.dart';

void main() {
  void twists(Twist twist, Map<String, String?> words) {
    words.forEach((word, twisted) => expect(twist.apply(word), twisted, reason: '${twist.name} $word'));
  }

  test('each twist spells the words it suits as its examples say', () {
    for (final twist in Twist.values) {
      for (final example in twist.example.split(', ')) {
        final [word, twisted] = example.split(' → ');
        expect(twist.apply(word), twisted, reason: example);
      }
    }
  });

  test('dropping a vowel keeps to -er, -tor and -le, and to words it reads well in', () {
    twists(Twist.dropVowel, {
      'tumbler': 'tumblr',
      'vector': 'vectr',
      'simple': 'simpl',
      'water': 'watr',
      'dancer': null, // "dank-r"
      'researcher': null, // Too long.
      'flower': null, // After w.
      'whale': null, // After a vowel.
      'river': 'rivr',
      'her': null,
    });
  });

  test('i to y keeps to one-syllable words where the i reads the same', () {
    twists(Twist.iToY, {
      'fire': 'fyre',
      'link': 'lynk',
      'white': 'whyte',
      'bright': null,
      'thirst': null,
      'circle': null,
      'bill': null,
      'stick': null,
      'bridge': null,
      'switch': null,
      'midst': null,
      'ink': null,
      'kit': null, // Too short.
      'quilt': null,
    });
  });

  test('-ight to -ite, but not where it says something else', () {
    twists(Twist.ightToIte, {
      'night': 'nite',
      'spotlight': 'spotlite',
      'weight': null,
      'height': null,
      'fighter': null,
      'mighty': null,
    });
  });

  test('c to k at the start and the end of short words', () {
    twists(Twist.cToK, {
      'click': 'klik',
      'crisp': 'krisp',
      'epic': 'epik',
      'quark': 'kwark',
      'chrome': null,
      'cent': null, // A soft c.
      'comment': null,
      'comfortable': null,
    });
  });

  test('doubling the last letter keeps to short one-syllable words', () {
    twists(Twist.doubleLast, {
      'star': 'starr',
      'ship': 'shipp',
      'iron': null,
      'boot': null,
      'armed': null,
      'box': null,
    });
  });

  test('endings go on the words they suit', () {
    expect([for (final ending in Ending.values) ending.apply('jet')], ['jetly', 'jetify', 'jetio', 'jetster', 'jetsy', 'jetHub']);
    final cases = {
      (Ending.ify, 'shape'): 'shapify',
      (Ending.ify, 'candy'): 'candify',
      (Ending.ify, 'radio'): null,
      (Ending.ify, 'honey'): null,
      (Ending.ify, 'odds'): null,
      (Ending.io, 'thigh'): null,
      (Ending.ly, 'happy'): null,
      (Ending.ly, 'simple'): null,
      (Ending.ly, 'cool'): null,
      (Ending.ster, 'just'): null,
      (Ending.sy, 'stand'): null,
      (Ending.hub, 'dash'): null,
      (Ending.ly, 'naked'): null,
    };
    cases.forEach((key, ended) => expect(key.$1.apply(key.$2), ended, reason: '$key'));
  });
}
