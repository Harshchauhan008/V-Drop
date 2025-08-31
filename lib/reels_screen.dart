import 'package:flutter/material.dart';
import 'package:spotvibe/profile_screen.dart';
import 'package:video_player/video_player.dart';


class ReelScreen extends StatefulWidget {
  final List<MediaItem> reels;
  final int initialIndex;
  const ReelScreen({
    super.key,
    required this.reels,
    required this.initialIndex,
  });


  @override
  State<ReelScreen> createState() => _ReelScreenState();
}
class _ReelScreenState extends State<ReelScreen> {
  late PageController _pageController;
  late List<VideoPlayerController> _controllers;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _controllers = widget.reels.map((item) {
      return VideoPlayerController.network(item.url)
        ..initialize().then((_) {
          setState(() {});
        })
        ..setLooping(true);
    }).toList();

    // Autoplay initial
    _controllers[widget.initialIndex].play();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    for (var controller in _controllers) {
      controller.pause();
    }
    _controllers[index].play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: widget.reels.length,
        itemBuilder: (context, index) {
          final item = widget.reels[index];
          final controller = _controllers[index];

          return Stack(
            fit: StackFit.expand,
            children: [
              controller.value.isInitialized
                  ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
                  : const Center(child: CircularProgressIndicator()),

              // UI Overlay
              Positioned(
                top: 50,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    const CircleAvatar(radius: 25),
                    const SizedBox(width: 8),
                    Text(
                      item.uploaderId,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Positioned(
                right: 16,
                bottom: 120,
                child: Column(
                  children: const [
                    Icon(Icons.favorite, color: Colors.white),
                    SizedBox(height: 16),
                    Icon(Icons.comment, color: Colors.white),
                    SizedBox(height: 16),
                    Icon(Icons.share, color: Colors.white),
                    SizedBox(height: 16),
                    Icon(Icons.more_vert, color: Colors.white),
                  ],
                ),
              ),

              Positioned(
                bottom: 32,
                left: 16,
                right: 16,
                child: Text(
                  item.caption,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

