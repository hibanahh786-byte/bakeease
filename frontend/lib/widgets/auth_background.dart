import 'package:flutter/material.dart';

class AuthBackgroundLayout extends StatelessWidget {
  final Widget child;

  const AuthBackgroundLayout({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5), // Match logo background
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _AuthBackgroundPainter(),
            ),
          ),
          SafeArea(
            child: child,
          ),
        ],
      ),
    );
  }
}

class _AuthBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // 1. Top-Right Soft Pink Blob
    final Path topRightPath = Path();
    topRightPath.moveTo(size.width * 0.4, 0);
    topRightPath.quadraticBezierTo(
      size.width * 0.6, size.height * 0.15,
      size.width, size.height * 0.08,
    );
    topRightPath.lineTo(size.width, 0);
    topRightPath.close();

    paint.color = const Color(0xFFFFE5E0).withOpacity(0.6);
    canvas.drawPath(topRightPath, paint);

    // 2. An outer boundary wave for the Top-Right Blob (gives depth)
    final Path topRightOuterPath = Path();
    topRightOuterPath.moveTo(size.width * 0.25, 0);
    topRightOuterPath.quadraticBezierTo(
      size.width * 0.55, size.height * 0.22,
      size.width, size.height * 0.12,
    );
    topRightOuterPath.lineTo(size.width, 0);
    topRightOuterPath.close();

    paint.color = const Color(0xFFFFEAE5).withOpacity(0.4);
    canvas.drawPath(topRightOuterPath, paint);

    // 3. Bottom Large Soft Pink Wave
    final Path bottomWavePath = Path();
    bottomWavePath.moveTo(0, size.height * 0.85);
    bottomWavePath.quadraticBezierTo(
      size.width * 0.35, size.height * 0.78,
      size.width * 0.7, size.height * 0.88,
    );
    bottomWavePath.quadraticBezierTo(
      size.width * 0.88, size.height * 0.92,
      size.width, size.height * 0.82,
    );
    bottomWavePath.lineTo(size.width, size.height);
    bottomWavePath.lineTo(0, size.height);
    bottomWavePath.close();

    paint.color = const Color(0xFFFFE5E0).withOpacity(0.7);
    canvas.drawPath(bottomWavePath, paint);

    // 4. An additional bottom layer wave to match the mockup's layered wavy look
    final Path bottomLayer2Path = Path();
    bottomLayer2Path.moveTo(0, size.height * 0.9);
    bottomLayer2Path.quadraticBezierTo(
      size.width * 0.45, size.height * 0.84,
      size.width * 0.8, size.height * 0.94,
    );
    bottomLayer2Path.quadraticBezierTo(
      size.width * 0.9, size.height * 0.96,
      size.width, size.height * 0.9,
    );
    bottomLayer2Path.lineTo(size.width, size.height);
    bottomLayer2Path.lineTo(0, size.height);
    bottomLayer2Path.close();

    paint.color = const Color(0xFFFFECE8).withOpacity(0.5);
    canvas.drawPath(bottomLayer2Path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

