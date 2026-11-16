import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/link.dart';

/// The LoudVector look, from the "Ket" logo: |V⟩, Dirac's notation for the state
/// vector V, in violet on dark ink. The logo's SVGs are in
/// ~/Documents/claude/loudvector-logo/directions/c-ket/.
abstract final class Brand {
  static const violet = Color(0xFF5B3DF5);
  static const violetOnDark = Color(0xFF9C8CFF);
  static const ink = Color(0xFF16132E);
  static const inkOnDark = Color(0xFFF3F2FA);

  /// Where "Buy me chocolate" goes.
  static final chocolate = Uri.parse('https://ko-fi.com/irishfolklore');

  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colours = ColorScheme.fromSeed(
      seedColor: violet,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(primary: dark ? violetOnDark : violet, onSurface: dark ? inkOnDark : ink);
    return ThemeData(
      colorScheme: colours,
      fontFamily: 'Jost',
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}

/// The app icon: |V⟩ in white on a violet tile, drawn as the logo's icon.svg is.
class KetIcon extends StatelessWidget {
  const KetIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _KetIconPainter());
}

class _KetIconPainter extends CustomPainter {
  const _KetIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32); // icon.svg's viewBox is 32 square.
    final white = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRRect(RRect.fromLTRBR(0, 0, 32, 32, const Radius.circular(7)), Paint()..color = Brand.violet);
    canvas.drawRect(const Rect.fromLTRB(4.25, 7, 6.75, 25), white);
    canvas.drawPath(_polygon(const [(8.75, 9.5), (11.74, 9.5), (14.25, 15.44), (16.76, 9.5), (19.75, 9.5), (14.25, 22.5)]), white);
    canvas.drawPath(_polygon(const [(20.5, 7), (23.3, 7), (27.8, 16), (23.3, 25), (20.5, 25), (25, 16)]), white);
  }

  @override
  bool shouldRepaint(_KetIconPainter oldDelegate) => false;
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

/// The strip along the bottom: whose app it is, and a link to buy them chocolate.
class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    return Material(
      color: colours.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              const KetIcon(size: 20),
              const SizedBox(width: 8),
              const Text('LoudVector', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              const Spacer(),
              Link(
                uri: Brand.chocolate,
                target: LinkTarget.blank,
                builder: (context, open) => TextButton.icon(
                  onPressed: open,
                  icon: const _ChocolateBar(),
                  label: const Text('Buy me chocolate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A little bar of chocolate, two squares by three.
class _ChocolateBar extends StatelessWidget {
  const _ChocolateBar();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: const Size(14, 18),
      painter: _ChocolatePainter(dark ? const Color(0xFFC08A63) : const Color(0xFF7B4A2E)),
    );
  }
}

class _ChocolatePainter extends CustomPainter {
  const _ChocolatePainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colour;
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 2; column++) {
        canvas.drawRRect(
          RRect.fromLTRBR(1 + column * 6.5, row * 6.2, 6.5 + column * 6.5, 5.2 + row * 6.2, const Radius.circular(1.2)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChocolatePainter oldDelegate) => oldDelegate.colour != colour;
}
