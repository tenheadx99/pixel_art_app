import 'package:flutter/material.dart';
import '../../providers/coloring_provider.dart';
import '../theme/app_style.dart';

class NumberToolbar extends StatelessWidget {
  final ColoringProvider provider;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const NumberToolbar({
    super.key,
    required this.provider,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppStyle.primary.withAlpha(15),
            AppStyle.secondary.withAlpha(10),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha(60),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(
            icon: Icons.undo_rounded,
            label: 'Undo',
            color: AppStyle.primary,
            onTap: provider.canUndo ? provider.undo : null,
          ),
          _buildDivider(),
          _ToolButton(
            icon: Icons.auto_fix_high_rounded,
            label: 'Fill',
            color: AppStyle.accent,
            onTap: () => provider.fillAllOfSelectedNumber(),
          ),
          _buildDivider(),
          _ToolButton(
            icon: provider.showNumbers ? Icons.format_list_numbered_rtl : Icons.format_size,
            label: 'Nums',
            color: AppStyle.gold,
            onTap: provider.toggleNumbers,
          ),
          _buildDivider(),
          _ToolButton(
            icon: Icons.restart_alt_rounded,
            label: 'Reset',
            color: AppStyle.coral,
            onTap: onReset,
          ),
          _buildDivider(),
          _ToolButton(
            icon: Icons.save_rounded,
            label: 'Save',
            color: AppStyle.mint,
            onTap: onSave,
          ),
          _buildDivider(),
          _ToolButton(
            icon: Icons.done_all_rounded,
            label: 'Auto',
            color: const Color(0xFF00B894),
            onTap: () => provider.fillAllRemaining(),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.black.withAlpha(10),
    );
  }
}

class _ToolButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onTap == null;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, _) => Transform.scale(
        scale: _scaleAnim.value,
        child: GestureDetector(
          onTapDown: isDisabled
              ? null
              : (_) {
                  _animController.forward();
                  _isPressed = true;
                },
          onTapUp: isDisabled
              ? null
              : (_) {
                  _animController.reverse();
                  _isPressed = false;
                  widget.onTap?.call();
                },
          onTapCancel: () {
            if (_isPressed) {
              _animController.reverse();
              _isPressed = false;
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 22,
                  color: isDisabled
                      ? Colors.grey.shade300
                      : widget.color,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDisabled
                        ? Colors.grey.shade300
                        : widget.color.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
