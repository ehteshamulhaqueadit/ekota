import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class MediaCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> videoUrls;
  const MediaCarousel(
      {super.key, required this.imageUrls, required this.videoUrls});

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...widget.imageUrls.map((u) => _ImageSlide(url: u)),
      ...widget.videoUrls.map((u) => _VideoSlide(url: u)),
    ];

    if (items.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child:
              Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 220,
            enlargeCenterPage: true,
            viewportFraction: 0.9,
            onPageChanged: (i, _) => setState(() => _current = i),
          ),
          items: items.map((it) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: it,
            );
          }).toList(),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              items.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 12 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _current ? Colors.black : Colors.grey,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageSlide extends StatelessWidget {
  final String url;
  const _ImageSlide({required this.url});

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, __) =>
            Container(color: Colors.black12),
        errorWidget: (_, __, ___) => Container(
          color: Colors.black12,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
}

class _VideoSlide extends StatefulWidget {
  final String url;
  const _VideoSlide({required this.url});
  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  late VideoPlayerController _video;
  ChewieController? _chewie;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _chewie = ChewieController(
              videoPlayerController: _video,
              autoPlay: false,
              looping: false,
            );
          });
        }
      });
  }

  @override
  void dispose() {
    _video.dispose();
    _chewie?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _chewie == null
      ? Container(
          color: Colors.black12,
          child: const Center(child: CircularProgressIndicator()),
        )
      : Chewie(controller: _chewie!);
}
