import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class EditorGallery extends StatelessWidget {
  final List<String> imagePaths;
  final VoidCallback onPickImage;
  final ValueChanged<int> onRemoveImage;
  final ColorScheme scheme;
  final TextTheme tt;

  const EditorGallery({
    super.key,
    required this.imagePaths,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.scheme,
    required this.tt,
  });

  void _openImageViewer(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(paths: imagePaths, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextButton.icon(
          onPressed: onPickImage,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
          label: const Text('Добавить фото'),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Фото',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imagePaths.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return AddPhotoCard(scheme: scheme, onTap: onPickImage);
                }
                final imageIndex = i - 1;
                return ImageThumb(
                  path: imagePaths[imageIndex],
                  onRemove: () => onRemoveImage(imageIndex),
                  onTap: () => _openImageViewer(context, imageIndex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AddPhotoCard extends StatelessWidget {
  final ColorScheme scheme;
  final VoidCallback onTap;

  const AddPhotoCard({super.key, required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 84,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: scheme.primary,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageThumb extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const ImageThumb({
    super.key,
    required this.path,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (path.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: path,
        height: 180,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 250),
        fadeOutDuration: const Duration(milliseconds: 250),
        memCacheHeight: 400,
        placeholder: (ctx, url) => Container(
          height: 180,
          color: Colors.black.withValues(alpha: 0.05),
        ),
        errorWidget: (ctx, url, error) => const SizedBox.shrink(),
      );
    } else {
      imageWidget = Image.file(
        File(path),
        height: 180,
        fit: BoxFit.cover,
        cacheHeight: 400,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            imageWidget,
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageViewerScreen extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const ImageViewerScreen({super.key, required this.paths, required this.initialIndex});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.paths.length}'),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.paths.length,
        onPageChanged: (v) => setState(() => _current = v),
        itemBuilder: (ctx, i) {
          final path = widget.paths[i];
          Widget imageWidget;
          if (path.startsWith('http')) {
            imageWidget = CachedNetworkImage(
              imageUrl: path,
              fadeInDuration: const Duration(milliseconds: 250),
              fadeOutDuration: const Duration(milliseconds: 250),
              placeholder: (ctx, url) => Container(
                color: Colors.black.withValues(alpha: 0.2),
              ),
              errorWidget: (ctx, url, error) => const Icon(
                Icons.broken_image,
                color: Colors.white38,
                size: 64,
              ),
            );
          } else {
            imageWidget = Image.file(File(path));
          }
          return InteractiveViewer(child: Center(child: imageWidget));
        },
      ),
    );
  }
}
