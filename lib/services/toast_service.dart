import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

class AppToast {
  static OverlayEntry? _currentToast;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline,
    Color color = AppTheme.primaryLight,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentToast?.remove();
    _currentToast = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: _ToastWidget(
            message: message,
            icon: icon,
            color: color,
            onDismiss: () {
              if (_currentToast == entry) {
                entry.remove();
                _currentToast = null;
              }
            },
          ),
        ),
      ),
    );

    _currentToast = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (_currentToast == entry) {
        entry.remove();
        _currentToast = null;
      }
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.color.withValues(alpha: 0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.message,
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: widget.onDismiss,
                child: const Icon(Icons.close, size: 14, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
