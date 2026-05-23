import 'package:flutter/material.dart';
import '../../providers/coloring_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../theme/app_style.dart';

class NumberToolbar extends StatelessWidget {
  final ColoringProvider provider;
  final AppSettingsProvider settings;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const NumberToolbar({
    super.key,
    required this.provider,
    required this.settings,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
        border: Border.all(color: Colors.white.withAlpha(60), width: 1),
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
          _divider(),
          _ToolButton(
            icon: provider.isEraseMode
                ? Icons.auto_fix_high_rounded
                : Icons.auto_fix_high_rounded,
            label: provider.isEraseMode ? 'Erase' : 'Fill',
            color: provider.isEraseMode ? AppStyle.coral : AppStyle.accent,
            onTap: () => provider.toggleEraseMode(),
          ),
          _divider(),
          _BrushSelector(
            current: provider.brushSize,
            onChanged: provider.setBrushSize,
            isErase: provider.isEraseMode,
          ),
          _divider(),
          _ToolButton(
            icon: provider.showNumbers
                ? Icons.format_list_numbered_rtl
                : Icons.format_size,
            label: 'Nums',
            color: AppStyle.gold,
            onTap: provider.toggleNumbers,
          ),
          _divider(),
          _ToolButton(
            icon: Icons.done_all_rounded,
            label: 'Auto',
            color: const Color(0xFF00B894),
            onTap: () => provider.fillAllRemaining(),
          ),
          if (provider.achievements.isNotEmpty) ...[
            _divider(),
            _ToolButton(
              icon: Icons.emoji_events_rounded,
              label: '${provider.achievements.length}',
              color: AppStyle.gold,
              onTap: () => _showAchievements(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showAchievements(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber),
            SizedBox(width: 10),
            Text('Achievements'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: provider.achievements
                .map(
                  (id) => Chip(
                    avatar: const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Color(0xFF00B894),
                    ),
                    label: Text(provider.achievementName(id)),
                    backgroundColor: AppStyle.gold.withAlpha(20),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 24, color: Colors.black.withAlpha(10));
}

class _BrushSelector extends StatelessWidget {
  final int current;
  final bool isErase;
  final ValueChanged<int> onChanged;

  const _BrushSelector({
    required this.current,
    required this.isErase,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [1, 2, 3].map((s) {
        final active = s == current;
        return GestureDetector(
          onTap: () => onChanged(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: active
                  ? (isErase ? AppStyle.coral : AppStyle.primary)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active ? Colors.transparent : Colors.black.withAlpha(30),
              ),
            ),
            child: Center(
              child: Text(
                '$s',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
    final disabled = widget.onTap == null;
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, _) => Transform.scale(
        scale: _scaleAnim.value,
        child: GestureDetector(
          onTapDown: disabled
              ? null
              : (_) {
                  _animController.forward();
                  _isPressed = true;
                },
          onTapUp: disabled
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: disabled ? Colors.grey.shade300 : widget.color,
                ),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: disabled
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
