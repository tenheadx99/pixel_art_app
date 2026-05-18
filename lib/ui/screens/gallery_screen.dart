import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/database_service.dart';
import '../../data/models/user_artwork.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<UserArtwork> _artworks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtworks();
  }

  Future<void> _loadArtworks() async {
    final db = context.read<DatabaseService>();
    final saved = await db.getSavedArtworks();
    setState(() {
      _artworks = saved.map((m) => UserArtwork.fromJson(m)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Artwork', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D1B69), Color(0xFF6C5CE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _artworks.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _artworks.length,
                        itemBuilder: (context, index) {
                          final artwork = _artworks[index];
                          return _ArtworkCard(
                            artwork: artwork,
                            onDelete: () => _deleteArtwork(artwork),
                            onShare: () => _shareArtwork(artwork),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(20),
            ),
            child: const Icon(Icons.photo_library_outlined, size: 56, color: Colors.white38),
          ),
          const SizedBox(height: 20),
          const Text(
            'No saved artwork yet',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a pixel art and save it!',
            style: TextStyle(
              color: Colors.white.withAlpha(100),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteArtwork(UserArtwork artwork) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Artwork'),
        content: const Text('Are you sure you want to delete this?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final storage = context.read<LocalStorageService>();
      final db = context.read<DatabaseService>();
      final fileName = artwork.filePath.split('/').last;
      await storage.deleteFile(fileName);
      await db.deleteArtwork(artwork.id);
      _loadArtworks();
    }
  }

  void _shareArtwork(UserArtwork artwork) {
    final file = File(artwork.filePath);
    if (file.existsSync()) {
      Share.shareXFiles(
        [XFile(artwork.filePath)],
        text: '🎨 Check out my Pixel Art! Created with Pixel Art app.',
      );
    }
  }
}

class _ArtworkCard extends StatelessWidget {
  final UserArtwork artwork;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _ArtworkCard({
    required this.artwork,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withAlpha(15),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.file(
              File(artwork.filePath),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.white.withAlpha(10),
                child: const Icon(Icons.broken_image, color: Colors.white38, size: 40),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withAlpha(15), Colors.white.withAlpha(5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artwork.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(artwork.dateCreated),
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _SmallIconButton(
                      icon: Icons.share,
                      onTap: onShare,
                    ),
                    const SizedBox(width: 4),
                    _SmallIconButton(
                      icon: Icons.delete,
                      onTap: onDelete,
                      color: const Color(0xFFFF6B6B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _SmallIconButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: color ?? Colors.white70,
        ),
      ),
    );
  }
}
