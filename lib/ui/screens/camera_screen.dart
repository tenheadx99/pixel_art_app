import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/camera_provider.dart';
import '../../providers/coloring_provider.dart';
import '../../config/app_constants.dart';
import '../../ui/theme/app_style.dart';
import '../../ui/screens/coloring_screen.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CameraProvider(),
      child: _CameraScreenBody(),
    );
  }
}

class _CameraScreenBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, camera, _) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Pixel Art Camera', style: TextStyle(color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D1B69), Color(0xFF6C5CE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (camera.selectedImage == null)
                      _buildPickArea(context, camera)
                    else
                      _buildPreview(context, camera),

                    if (camera.selectedImage != null) ...[
                      const SizedBox(height: 20),
                      _buildSettingsCard(context, camera),
                      const SizedBox(height: 16),
                      _buildConvertButton(context, camera),
                    ],

                    if (camera.convertedArt != null) ...[
                      const SizedBox(height: 24),
                      _buildResultCard(context, camera),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickArea(BuildContext context, CameraProvider camera) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(20), Colors.white.withAlpha(10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withAlpha(30), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(20),
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 48,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Turn any photo into pixel art!',
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose from gallery or take a photo',
            style: TextStyle(
              color: Colors.white.withAlpha(120),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IconButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => _pickImage(context, camera, ImageSource.gallery),
              ),
              const SizedBox(width: 20),
              _IconButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => _pickImage(context, camera, ImageSource.camera),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, CameraProvider camera) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(
          image: MemoryImage(camera.selectedImage!),
          fit: BoxFit.contain,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                camera.clear();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, CameraProvider camera) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(25), Colors.white.withAlpha(10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingRow(
            context,
            label: 'Grid Size',
            options: AppConstants.supportedGridSizes
                .map((s) => _Option(label: '${s}x$s', value: s))
                .toList(),
            selectedValue: camera.gridSize,
            onSelected: (v) => camera.setGridSize(v as int),
          ),
          const SizedBox(height: 12),
          _buildSettingRow(
            context,
            label: 'Colors',
            options: [8, 12, 16, 24]
                .map((c) => _Option(label: '$c', value: c))
                .toList(),
            selectedValue: camera.maxColors,
            onSelected: (v) => camera.setMaxColors(v as int),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String label,
    required List<_Option> options,
    required dynamic selectedValue,
    required void Function(dynamic) onSelected,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(170),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((opt) {
              final isSelected = opt.value == selectedValue;
              return GestureDetector(
                onTap: () => onSelected(opt.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [AppStyle.primary, AppStyle.secondary],
                          )
                        : null,
                    color: isSelected ? null : Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withAlpha(20),
                    ),
                  ),
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildConvertButton(BuildContext context, CameraProvider camera) {
    return GestureDetector(
      onTap: camera.isConverting
          ? null
          : () => _convert(context, camera),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppStyle.secondary, AppStyle.primary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppStyle.primary.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: camera.isConverting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Convert to Pixel Art',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, CameraProvider camera) {
    final art = camera.convertedArt!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [const Color(0xFF00B894).withAlpha(40), const Color(0xFF00CEC9).withAlpha(30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF00B894).withAlpha(60)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Color(0xFF00B894), size: 24),
              SizedBox(width: 8),
              Text(
                'Ready!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${art.gridWidth}x${art.gridHeight}  ·  ${art.colorCount} colors  ·  ${art.fillableCells} cells',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => camera.clear(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Another'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startColoring(context, art),
                  icon: const Icon(Icons.colorize),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B894),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(
      BuildContext context, CameraProvider camera, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (context.mounted) {
      camera.setImage(bytes);
    }
  }

  Future<void> _convert(BuildContext context, CameraProvider camera) async {
    await camera.convertImage('My Pixel Art');
  }

  void _startColoring(BuildContext context, art) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<ColoringProvider>(),
          child: ColoringScreen(art: art),
        ),
      ),
    );
  }
}

class _Option {
  final String label;
  final dynamic value;
  _Option({required this.label, required this.value});
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
