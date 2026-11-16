# Startup Name Generator

Endless startup name ideas, each with whether its .com is free. Live at
https://hughsheehy.github.io/flutterstartupnamer1/ (the built web app is published from the
`flutterstartupnamer1` repo).

It began as Google's "Write your first Flutter app" codelab (2021) and was brought up to
Flutter 3.50 in November 2026.

- **Names** come from the [`english_words`](https://pub.dev/packages/english_words) package,
  the ~4,300 most used English words: an adjective or noun, then a noun. Capitalized words
  (religions, nationalities, people) are left out.
- **Tech words** swaps one of the two words for one from `lib/tech_words.dart` (quark,
  pixel, argon…). Edit that list freely.
- **Longer words** lets in two-syllable words, for names of up to three syllables.
- **.com check**: each name asks the .com registry's public RDAP service
  (`rdap.verisign.com`), which answers 404 for a name nobody has registered. Two at a time,
  only for names on screen, each once. A name being free there doesn't promise any
  registrar will sell it at the standard price, so check before buying.
- Tap a name to save it; the list button shows the saved ones with their .com status.

## Building

```bash
flutter test
flutter build web --release --base-href /flutterstartupnamer1/
```

Then copy `build/web/` into the `flutterstartupnamer1` repo and push it; GitHub Pages
serves it from there.
