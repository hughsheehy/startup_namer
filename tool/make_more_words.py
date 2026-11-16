#!/usr/bin/env python3
"""Makes lib/more_words.dart, the extra words behind the "More words" option.

Nouns and adjectives from the 25,000 most common English words, as wordfreq
ranks them, that english_words doesn't already have:

- what each word is comes from WordNet 3.0: a word counts as a noun or an
  adjective if WordNet has it as one, and that's a fair share of how its senses
  were used in WordNet's tagged texts (so "will" and "make", mostly verbs, are
  out), or of its senses if none were tagged;
- left out: another word's plural ("years"), -ing form ("going") or -ed form
  ("played") unless WordNet's texts use it as a word in its own right
  ("building", "married"), plurals of words already in either list
  ("viewers"), comparatives ("higher"), irregular forms (men,
  made, said), numbers, words about religion or atrocities (christ,
  holocaust),
  names (words WordNet only has with a capital, like Paris, or that the
  system word list capitalizes and WordNet's texts never use as nouns, like
  Henry), small
  words like "the", "may" or "both", words of fewer than three letters, words any of
  whose WordNet senses is described as offensive, vulgar, sexual and so on,
  words on the LDNOOBW list of offensive words, and english_words' own unsafe
  words.

Usage, with the data downloaded somewhere (not kept in the repo):
  python3 tool/make_more_words.py \\
      --wordfreq wordfreq-en-25000-log.json   # github.com/aparrish/wordfreq-en-25000
      --wordnet wordnet/                      # WordNet 3.0 database files (index.*, data.*, cntlist.rev)
      --offensive ldnoobw-en.txt              # github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words
"""
import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'lib' / 'more_words.dart'

# Words that are mostly grammar, which WordNet sometimes has as nouns too
# ("may" the hawthorn, "will" the testament).
SMALL_WORDS = set('''
be am is are was were been being have has had having do does did done doing will would shall should can could may
might must ought the and or nor but yet if then than so as at by for from in into of on onto to with within without
about above across after against along among around before behind below beneath beside between beyond during
except inside near off out outside over past since through throughout till toward towards under underneath until up
upon via me my mine we us our ours you your yours he him his she her hers it its they them their theirs this that
these those who whom whose which what whatever when where why how not no yes all any each every some such own
very too also just only even still here there now ago per yeah okay hey oh gonna wanna lol etc
more most much many less least few fewer last same both another other else next several enough further former
latter various someone somebody something anyone anybody anything everyone everybody everything nothing nobody none
wow yep nope hello bye please thanks sorry percent neither either latest means remains behalf thou thee thy yea cant
sec min pic sept calif gen ain whilst
one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen
nineteen twenty thirty forty fifty sixty seventy eighty ninety hundred thousand million billion trillion dozen
first second third fourth fifth sixth seventh eighth ninth tenth twelfth twentieth hundredth thousandth
'''.split())

# Words that aren't offensive but would be poor in a made-up name: religion,
# atrocities and the like.
SENSITIVE = set('''
christ jesus allah pope papal mosque synagogue satan satanic holocaust genocide nazi nazis fascist fascism communist
communism jihad terrorist terrorism suicide slavery slave slaves massacre cyanide euthanasia miscarriage abortion
cancer tumour tumor corpse funeral coffin
'''.split())

# Words in a WordNet sense's description that mark the word as one to leave out.
FLAGGED = re.compile(
    r'\b(offensive|vulgar|obscene|obscenity|slur|derogatory|disparaging|contemptuous|insulting|racist|'
    r'sexual|sexually|genital|genitals|penis|vagina|vulva|breasts?|buttocks|anus|excrement|feces|faeces|'
    r'urine|urinate|copulat\w*|intercourse|prostitut\w*|masturbat\w*|pornograph\w*|erotic)\b',
    re.I,
)

POS_OF_SS_TYPE = {'1': 'n', '2': 'v', '3': 'a', '4': 'r', '5': 'a'}  # 5: adjective satellite


def read_english_words():
    """english_words' own adjectives, nouns and unsafe words, from the pub cache."""
    config = json.loads((ROOT / '.dart_tool' / 'package_config.json').read_text())
    root = next(p['rootUri'] for p in config['packages'] if p['name'] == 'english_words')
    words = Path(root.removeprefix('file://')) / 'lib' / 'src' / 'words'

    def entries(name):
        return {w.lower() for w in re.findall(r"^\s*'([^']+)',", (words / name).read_text(), re.M)}

    unsafe_text = (words / 'unsafe.dart').read_text()
    unsafe = {w.lower() for w in re.findall(r"'([^']+)'", unsafe_text[: unsafe_text.index('unsafePairs')])}
    return entries('adjectives.dart') | entries('nouns.dart'), unsafe


def read_wordnet(folder):
    """For each lowercase one-word lemma: senses and tagged uses per part of
    speech, the words WordNet writes in lower case as nouns and as adjectives
    (not only with a capital, like Paris or French), whether any sense is
    flagged, and the irregular forms of other words (men, made, said)."""
    senses = defaultdict(lambda: defaultdict(int))
    tagged = defaultdict(lambda: defaultdict(int))
    lower_case = {'n': set(), 'a': set()}
    flagged = set()
    forms_of = {}  # (pos, offset) -> {form in lower case: form as WordNet writes it}
    for pos in ('noun', 'verb', 'adj', 'adv'):
        for line in (folder / f'index.{pos}').read_text(errors='replace').splitlines():
            if line.startswith(' '):
                continue
            fields = line.split()
            lemma, p, count = fields[0], fields[1], int(fields[2])
            senses[lemma]['a' if p in 'as' else p] += count
        for line in (folder / f'data.{pos}').read_text(errors='replace').splitlines():
            if line.startswith(' '):
                continue
            head, _, gloss = line.partition(' | ')
            fields = head.split()
            count = int(fields[3], 16)
            forms = [re.sub(r'\(.*\)$', '', fields[4 + 2 * i]) for i in range(count)]
            forms_of[({'noun': 'n', 'verb': 'v', 'adj': 'a', 'adv': 'r'}[pos], fields[0])] = {
                form.lower(): form for form in forms}
            for form in forms:
                if pos in ('noun', 'adj') and form == form.lower():
                    lower_case[pos[0]].add(form)
                if FLAGGED.search(gloss):
                    flagged.add(form.lower())
    # Tagged uses per sense, leaving out senses WordNet writes with a capital, so
    # "berlin" (a carriage) doesn't count Berlin the city's.
    for line in (folder / 'index.sense').read_text(errors='replace').splitlines():
        key, offset, _, uses = line.split()
        lemma, _, rest = key.partition('%')
        pos = POS_OF_SS_TYPE[rest[0]]
        form = forms_of.get(('a' if pos == 'a' else pos, offset), {}).get(lemma, lemma)
        if form == form.lower():
            tagged[lemma][pos] += int(uses)
    irregular = set()
    for pos in ('noun', 'verb', 'adj'):
        for line in (folder / f'{pos}.exc').read_text(errors='replace').splitlines():
            form, *bases = line.split()
            if any(base != form for base in bases):
                irregular.add(form)
    return senses, tagged, lower_case, flagged, irregular


def comparative(word, senses, tagged):
    """Whether adjective `word` is another's -er or -est form ("higher",
    "latest"), rather than one in its own right ("bitter", "proper")."""
    for ending in ('est', 'er'):
        if word.endswith(ending):
            stem = word[: -len(ending)]
            stems = [stem, stem + 'e'] + ([stem[:-1]] if len(stem) > 2 and stem[-1] == stem[-2] else [])
            stems += [stem[:-1] + 'y'] if stem.endswith('i') else []
            bases = [s for s in stems if senses.get(s, {}).get('a')]
            if bases:
                base = max(tagged.get(s, {}).get('a', 0) for s in bases)
                return tagged.get(word, {}).get('a', 0) < max(5, 0.5 * base)
    return False


def inflected(word, pos, senses, tagged):
    """Whether `word`, as a noun or adjective (`pos`), is really another word's
    plural ("years"), -ing form ("going") or -ed form ("played"), rather than a
    word in its own right ("news", "building", "married"): kept if it's used as
    one often enough in WordNet's tagged texts."""
    own = tagged.get(word, {}).get(pos, 0)
    if pos == 'n' and word.endswith('s') and not word.endswith('ss'):
        stems = [word[:-1], word[:-2], word[:-3] + 'y'] if word.endswith('ies') else [word[:-1], word[:-2]]
        nouns = [stem for stem in stems if senses.get(stem, {}).get('n')]
        if nouns:
            return own == 0 or own < max(tagged.get(stem, {}).get('n', 0) for stem in nouns)
    stems = []
    if word.endswith('ing'):
        stem = word[:-3]
        stems = [stem, stem + 'e'] + ([stem[:-1]] if len(stem) > 2 and stem[-1] == stem[-2] else [])
    elif word.endswith('ed'):
        stems = [word[:-2], word[:-1]] + ([word[:-3]] if len(word) > 4 and word[-3] == word[-4] else [])
        stems += [word[:-3] + 'y'] if word.endswith('ied') else []
    verbs = [stem for stem in stems if senses.get(stem, {}).get('v')]
    if not verbs:
        return False
    base = max(sum(tagged.get(stem, {}).values()) for stem in verbs)
    if pos == 'a' and word.endswith('ed'):
        # Participles make poor names ("based", "located"): only ones used as
        # adjectives about half as much as their verb ("detailed", "tired").
        return own < 0.5 * base
    return not (own >= 9 or own >= 0.2 * base)


def kinds(word, senses, tagged):
    """The parts of speech `word` counts as here: a fair share of its tagged
    uses, or of its senses if it has few tagged uses."""
    s, t = senses.get(word, {}), tagged.get(word, {})
    total_tagged = sum(t.values())
    found = set()
    for pos in ('n', 'a'):
        if not s.get(pos):
            continue
        if total_tagged >= 4:
            share = t.get(pos, 0) / total_tagged
        else:
            share = s[pos] / sum(s.values())
        if share >= 0.3:
            found.add(pos)
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--wordfreq', type=Path, required=True)
    parser.add_argument('--wordnet', type=Path, required=True)
    parser.add_argument('--offensive', type=Path, required=True)
    parser.add_argument('--names', type=Path, default=Path('/usr/share/dict/words'),
                        help='a word list with names capitalized, like /usr/share/dict/words')
    args = parser.parse_args()

    ranked = [word for word, _ in json.loads(args.wordfreq.read_text())]
    # Names: listed with a capital (Henry, Martin, Carter), and never used as an
    # ordinary noun in WordNet's tagged texts, though WordNet has them as rare
    # words (a henry is a unit, a martin a bird).
    capitalized = {line.strip().lower() for line in args.names.read_text(errors='replace').splitlines()
                   if line[:1].isupper() and line.strip().isalpha()}
    offensive = {line.strip().lower() for line in args.offensive.read_text().splitlines() if line.strip()}
    have, unsafe = read_english_words()
    senses, tagged, lower_case, flagged, irregular = read_wordnet(args.wordnet)

    adjectives, nouns = [], []
    for word in ranked:
        if not re.fullmatch(r'[a-z]{3,14}', word) or word in have or word in SMALL_WORDS:
            continue
        if word in offensive or word in unsafe or word in flagged or word in irregular or word in SENSITIVE:
            continue
        if re.fullmatch(r'x{0,3}(ix|iv|v?i{0,3})', word) or word.endswith('teenth'):  # iii, seventeenth
            continue
        found = kinds(word, senses, tagged)
        if 'a' in found and word in lower_case['a'] and not inflected(word, 'a', senses, tagged) \
                and not comparative(word, senses, tagged):
            adjectives.append(word)
        is_name = word in capitalized and not tagged.get(word, {}).get('n')
        if 'n' in found and word in lower_case['n'] and not inflected(word, 'n', senses, tagged) and not is_name:
            nouns.append(word)

    # Plurals whose singular is already a word here or in english_words ("viewers",
    # "stairs"); words like "princess", "census" or "physics" stay.
    singular = set(nouns) | have
    def plural(word):
        if not word.endswith('s') or word.endswith(('ss', 'us', 'is', 'ics')):
            return False
        stems = [word[:-1]] + ([word[:-2]] if word.endswith('es') else []) + ([word[:-3] + 'y'] if word.endswith('ies') else [])
        return any(stem in singular for stem in stems)
    nouns = [word for word in nouns if not plural(word)]

    def dart_list(name, words):
        lines, line = [], '  '
        for word in words:
            item = f"'{word}', "
            if len(line) + len(item) > 118:
                lines.append(line.rstrip())
                line = '  '
            line += item
        lines.append(line.rstrip())
        return f'const {name} = <String>[\n' + '\n'.join(lines) + '\n];\n'

    OUT.write_text(f'''// Made by tool/make_more_words.py: change that, not this.
//
// The extra words behind the "More words" option: {len(adjectives):,} adjectives and
// {len(nouns):,} nouns from the 25,000 most common English words, as wordfreq ranks
// them, that english_words doesn't already have, most common first. What each
// word is comes from WordNet 3.0.
//
// This word list is made from wordfreq's data, by Robyn Speer, which includes
// data from SUBTLEX and other sources (https://github.com/rspeer/wordfreq), and
// like it is available under the Creative Commons Attribution-ShareAlike 4.0
// licence (https://creativecommons.org/licenses/by-sa/4.0/).
//
// It is also made with WordNet 3.0, whose licence asks for this notice:
//
// WordNet 3.0 Copyright 2006 by Princeton University. All rights reserved.
// THIS SOFTWARE AND DATABASE IS PROVIDED "AS IS" AND PRINCETON UNIVERSITY MAKES
// NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED. BY WAY OF EXAMPLE, BUT
// NOT LIMITATION, PRINCETON UNIVERSITY MAKES NO REPRESENTATIONS OR WARRANTIES OF
// MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE OR THAT THE USE OF THE
// LICENSED SOFTWARE, DATABASE OR DOCUMENTATION WILL NOT INFRINGE ANY THIRD PARTY
// PATENTS, COPYRIGHTS, TRADEMARKS OR OTHER RIGHTS.

// ignore_for_file: lines_longer_than_80_chars

{dart_list('extraAdjectives', adjectives)}
{dart_list('extraNouns', nouns)}''')
    print(f'{OUT.relative_to(ROOT)}: {len(adjectives)} adjectives, {len(nouns)} nouns')


if __name__ == '__main__':
    main()
