import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/link.dart';

/// The LoudVector look, from the "Ket" logo: |V⟩, Dirac's notation for the state
/// vector V, in violet on dark ink. The logo's files are in assets/logo/, copied
/// from brand/final/ in the hughsheehy/loudvector repo.
abstract final class Brand {
  static const violet = Color(0xFF5B3DF5);
  static const violetOnDark = Color(0xFF9C8CFF);
  static const ink = Color(0xFF16132E);
  static const inkOnDark = Color(0xFFF3F2FA);

  /// Where "If you like it, buy me chocolate." goes.
  static final chocolate = Uri.parse('https://ko-fi.com/loudvector');

  /// Where "Built by LoudVector" goes.
  static final home = Uri.parse('https://loudvector.com');

  /// The questions and answers page (web/faq.html). Cloudflare serves it at
  /// /faq, and redirects faq.html there.
  static final faq = Uri.parse('faq');

  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colours = ColorScheme.fromSeed(
      seedColor: violet,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(primary: dark ? violetOnDark : violet, onSurface: dark ? inkOnDark : ink);
    return ThemeData(
      colorScheme: colours,
      fontFamily: 'Outfit',
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}

/// [text] between the logo's violet bar and angle bracket, like |LoudVector⟩.
class KetTitle extends StatelessWidget {
  const KetTitle(this.text, {super.key, this.fontSize = 22});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colour = Theme.of(context).colorScheme.primary;
    // As in lockup-light.svg, where the brackets are 52 high around 40-high
    // capitals: the bar 5 wide, the bracket 17.5 wide.
    final height = fontSize * 1.05;
    return Semantics(
      label: text,
      excludeSemantics: true,
      // On a very narrow screen, smaller rather than cut off.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: height * 5 / 52, height: height, color: colour),
            SizedBox(width: height * 0.22),
            Text(text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
            SizedBox(width: height * 0.13),
            CustomPaint(size: Size(height * 17.5 / 52, height), painter: _BracketPainter(colour)),
          ],
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.height / 52);
    canvas.drawPath(_polygon(const [(0, 0), (5.5, 0), (17.5, 26), (5.5, 52), (0, 52), (12, 26)]), Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) => oldDelegate.colour != colour;
}

Path _polygon(List<(double, double)> points) => Path()
  ..addPolygon([for (final (x, y) in points) Offset(x, y)], true);

/// The strip along the bottom, as in the transport apps: a pill-shaped link to buy
/// chocolate, and below it "Built by LoudVector" with the logo, linking to
/// loudvector.com.
class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colours = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final chocolate = Link(
      uri: Brand.chocolate,
      target: LinkTarget.blank,
      builder: (context, open) => OutlinedButton(
        onPressed: open,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const StadiumBorder(),
          side: BorderSide(color: colours.outlineVariant),
          backgroundColor: colours.surface,
          foregroundColor: colours.onSurface,
          // The theme's own button text (Outfit), not a bare style that drops the font.
          textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: const Text('🍫 If you like it, buy me chocolate.'),
      ),
    );
    final builtBy = Link(
      uri: Brand.home,
      target: LinkTarget.blank,
      builder: (context, open) => TextButton(
        onPressed: open,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: colours.onSurfaceVariant,
        ),
        child: Semantics(
          label: 'Built by LoudVector',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Built by', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: colours.onSurfaceVariant)),
              const SizedBox(width: 10),
              SvgPicture.asset('assets/logo/icon-small.svg', width: 22, height: 22),
              const SizedBox(width: 8),
              SvgPicture.asset('assets/logo/lockup-${dark ? 'dark' : 'light'}.svg', height: 18),
            ],
          ),
        ),
      ),
    );
    // In a tab of its own, so the list and saved names stay as they are.
    final faq = Link(
      uri: Brand.faq,
      target: LinkTarget.blank,
      builder: (context, open) => TextButton(
        onPressed: open,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: colours.primary,
          textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        child: const Text('FAQ'),
      ),
    );
    return Material(
      color: colours.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              chocolate,
              const SizedBox(height: 14),
              // Side by side, or one above the other on a very narrow screen.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [builtBy, faq],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
