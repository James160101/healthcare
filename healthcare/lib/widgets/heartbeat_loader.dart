import 'package:flutter/material.dart';

class HeartbeatLoader extends StatefulWidget {
  final double size;
  final Color color;
  final String? message;

  const HeartbeatLoader({
    super.key, 
    this.size = 80.0, 
    this.color = Colors.red,
    this.message,
  });

  @override
  State<HeartbeatLoader> createState() => _HeartbeatLoaderState();
}

class _HeartbeatLoaderState extends State<HeartbeatLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Rythme cardiaque lent (~50 BPM)
    );

    // Séquence pour imiter un battement "Doum-Doum... Pause"
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 10), // Battement 1
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),  // Relachement
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 5),   // Pause brève
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 10),// Battement 2 (plus petit)
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15), // Relachement
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),  // Pause longue
    ]).animate(_controller);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              Icons.favorite,
              color: widget.color,
              size: widget.size,
              shadows: [
                Shadow(
                  blurRadius: 20.0,
                  color: widget.color.withOpacity(0.5),
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 24),
            Text(
              widget.message!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
