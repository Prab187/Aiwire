import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool dark;
  const GoogleSignInButton({super.key, required this.onPressed, this.dark = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF161616) : Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: dark ? const Color(0xFF2E2E2E) : const Color(0xFFD9D9D9),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GIcon(size: 17),
            const SizedBox(width: 9),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: dark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1A1A),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GIcon extends StatelessWidget {
  final double size;
  const _GIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GIconPainter()),
    );
  }
}

class _GIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final sw = size.width * 0.195;

    final colors = [
      const Color(0xFF4285F4), // blue  — top right going clockwise
      const Color(0xFFEA4335), // red   — top left
      const Color(0xFFFBBC05), // yellow— bottom left
      const Color(0xFF34A853), // green — bottom right
    ];

    // Draw four colored arcs (each ~90°)
    final sweeps = [pi * 0.5, pi * 0.5, pi * 0.5, pi * 0.5];
    final starts = [-pi * 0.5, pi, pi * 0.5, 0.0];
    final rect = Rect.fromCircle(center: c, radius: r - sw / 2);

    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        rect,
        starts[i],
        sweeps[i],
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Horizontal crossbar
    final barY = c.dy;
    final barStart = Offset(c.dx, barY);
    final barEnd = Offset(c.dx + r - sw * 0.1, barY);
    canvas.drawLine(
      barStart, barEnd,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.butt,
    );

    // Vertical drop (right side of crossbar)
    canvas.drawLine(
      barEnd,
      Offset(barEnd.dx, barY + r * 0.52),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );
  }

  static const double pi = 3.141592653589793;

  @override
  bool shouldRepaint(_) => false;
}
