import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // ✅ REQUIRED for Uint8List
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotvibe/uploadpost_screen.dart';
import 'package:video_player/video_player.dart';

import 'map_screen.dart';

class AppImage {
  final String path;
  final double? latitude;
  final double? longitude;

  AppImage({required this.path, this.latitude, this.longitude});

  factory AppImage.fromJson(Map<String, dynamic> json) {
    return AppImage(
      path: json['imageUrl'],
      latitude: double.tryParse(json['location']?['latitude'] ?? ''),
      longitude: double.tryParse(json['location']?['longitude'] ?? ''),
    );
  }
}
class CameraScreen extends StatefulWidget {
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  List<CameraDescription>? cameras;
  bool isRearCameraSelected = true;
  bool flashOn = false;
  bool saveLocation = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    cameras = await availableCameras();
    controller = CameraController(
      isRearCameraSelected ? cameras!.first : cameras!.last,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<Position?> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _sendToServer(File file, Position? location) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';

    var request = http.MultipartRequest(
      'POST',
      Uri.parse("https://6ea8974672ed.ngrok-free.app/upload"),
    );

    request.fields['user_id'] = userId;
    if (location != null) {
      request.fields['latitude'] = location.latitude.toString();
      request.fields['longitude'] = location.longitude.toString();
    }
    request.files.add(await http.MultipartFile.fromPath('image', file.path));

    await request.send();
  }

  Future<void> _captureAndSave() async {
    if (!controller!.value.isInitialized) return;

    final XFile image = await controller!.takePicture();

    final dir = await getApplicationDocumentsDirectory();
    final savedImage = await File(image.path).copy(path.join(dir.path, path.basename(image.path)));

    Position? location;
    if (saveLocation) {
      location = await _getCurrentLocation();
    }

    await _sendToServer(savedImage, location);

    final metadataFile = File('${dir.path}/media_metadata.json');
    Map<String, dynamic> metadataMap = {};

    if (await metadataFile.exists()) {
      final content = await metadataFile.readAsString();
      metadataMap = jsonDecode(content);
    }

    metadataMap[savedImage.path] = {
      'latitude': location?.latitude,
      'longitude': location?.longitude,
    };

    await metadataFile.writeAsString(jsonEncode(metadataMap));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: controller == null || !controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          CameraPreview(controller!),

          // Top buttons
          Positioned(
            top: 40,
            left: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 100),
                IconButton(
                  icon: Icon(Icons.location_on, color: saveLocation ? Colors.red : Colors.white),
                  onPressed: () {
                    setState(() {
                      saveLocation = !saveLocation;
                    });
                  },
                ),
              ],
            ),
          ),

          // Flash & Switch
          Positioned(
            top: 40,
            right: 20,
            child: Column(
              children: [
                IconButton(
                  icon: Icon(flashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                  onPressed: () async {
                    flashOn = !flashOn;
                    await controller!.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  onPressed: () async {
                    isRearCameraSelected = !isRearCameraSelected;
                    await controller?.dispose();
                    _setupCamera();
                  },
                ),
              ],
            ),
          ),

          // Bottom buttons
          Positioned(
            bottom: 20,
            left: 30,
            child: IconButton(
              icon: const Icon(Icons.photo_library, size: 32, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryScreen()),
                );
              },
            ),
          ),

          // Capture button
          Positioned(
            bottom: 10,
            right: MediaQuery.of(context).size.width / 2 - 35,
            child: GestureDetector(
              onTap: _captureAndSave,
              child: Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(width: 4, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryScreen extends StatefulWidget {

  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();

}

class _GalleryScreenState extends State<GalleryScreen>with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late Timer _sliderTimer;
  int _currentPage = 0;
  late String userId;


  int selectedTab = 0; // 0 = Home, 1 = Camera Roll, 2 = Lock
  Map<String, List<Map<String, dynamic>>> groupedMedia = {};
  List<Map<String, dynamic>> mediaItems = [];
  late TabController _tabController;

  String searchQuery = "";
  List<AppImage> yourImageList = [];

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }



  @override
  void initState() {
    super.initState();
    _loadSavedMedia(); // Load saved image/video data with location
    _pageController = PageController();
    _startAutoSlide();
    fetchImagesFromServer();
    _tabController = TabController(length: 3, vsync: this);
    getUserId();
  }

  void getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString('userId');

    if (storedId != null) {
      setState(() {
        userId = storedId;
      });
    } else {
      // Handle missing userId (optional)
      debugPrint('No userId found in SharedPreferences');
    }
  }


  Future<void> fetchImagesFromServer() async {
    final response = await http.get(Uri.parse('https://6ea8974672ed.ngrok-free.app/images'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        setState(() {
          yourImageList = data.map((json) => AppImage.fromJson(json)).toList();
        });
      } else {
        print('❌ Unexpected data format');
      }
    } else {
      print('❌ Failed to load images: ${response.body}');
    }
  }


  Future<void> _loadSavedMedia() async {
    final dir = await getApplicationDocumentsDirectory();
    final metadataFile = File('${dir.path}/media_metadata.json');

    Map<String, dynamic> metadataMap = {};

    // Step 1: Read metadata file
    if (await metadataFile.exists()) {
      try {
        final content = await metadataFile.readAsString();
        metadataMap = jsonDecode(content);
        print("✅ Metadata loaded successfully");
      } catch (e) {
        print("❌ Error reading metadata file: $e");
      }
    } else {
      print("⚠️ No metadata file found");
    }

    // Step 2: Read media files
    final files = Directory(dir.path)
        .listSync()
        .where((file) =>
    file.path.endsWith(".jpg") || file.path.endsWith(".mp4"))
        .map((file) => File(file.path))
        .toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    // Step 3: Update UI
    setState(() {
      mediaItems.clear();
      groupedMedia.clear();

      for (var file in files) {
        final modified = file.lastModifiedSync();
        final key = DateFormat('MMMM yyyy').format(modified);

        final meta = metadataMap[file.path] ?? {};
        final lat = meta['latitude'];
        final lon = meta['longitude'];

        final mediaItem = {
          'path': file.path,
          'isVideo': file.path.endsWith('.mp4'),
          'isAsset': false,
          'latitude': lat,
          'longitude': lon,
        };

        // Add to groupedMedia
        groupedMedia.putIfAbsent(key, () => []);
        groupedMedia[key]!.add(mediaItem);

        // Add to flat list
        mediaItems.add(mediaItem);
      }
    });
  }


// Save image with location metadata
  Future<void> saveImageWithLocation(Uint8List imageBytes) async {
    final position = await _getCurrentLocation();
    final filePath = await _saveFile(imageBytes); // ← pass imageBytes here

    final dir = await getApplicationDocumentsDirectory();
    final metadataFile = File('${dir.path}/media_metadata.json');

    Map<String, dynamic> metadataMap = {};
    if (await metadataFile.exists()) {
      final content = await metadataFile.readAsString();
      metadataMap = jsonDecode(content);
    }

    metadataMap[filePath] = {
      'latitude': position?.latitude,
      'longitude': position?.longitude,
    };

    await metadataFile.writeAsString(jsonEncode(metadataMap));
  }

  Future<String> _saveFile(Uint8List imageBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime
        .now()
        .millisecondsSinceEpoch}.jpg';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(imageBytes); // ✅ Correct type
    return file.path;
  }


  Future<String> getLocationName(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return '${placemark.locality}, ${placemark.subAdministrativeArea ?? placemark.administrativeArea}';
      }
    } catch (e) {
      print('Error getting location name: $e');
    }
    return 'Unknown Location';
  }


  Future<String> _buildPopupLocationText() async {
    if (_currentPage >= mediaItems.length) return 'Location not available';

    final currentMedia = mediaItems[_currentPage];
    final lat = currentMedia['latitude'];
    final lng = currentMedia['longitude'];

    if (lat != null && lng != null) {
      return await getLocationName(lat, lng);
    }
    return 'Location not available';
  }



// Get current geolocation
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }


  void _startAutoSlide() {
    _sliderTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < mediaItems.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.blue),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                ),
                onChanged: (val) {
                  setState(() => searchQuery = val.toLowerCase());
                },
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  // Handle edit
                } else if (value == 'delete') {
                  // Handle delete
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: FutureBuilder<String>(
                    future: _buildPopupLocationText(),
                    builder: (context, snapshot) {
                      final location = snapshot.data ?? 'Fetching...';

                      final currentMedia = _currentPage < mediaItems.length
                          ? mediaItems[_currentPage]
                          : null;
                      final fileDate = currentMedia != null
                          ? File(currentMedia['path']).lastModifiedSync()
                          : DateTime.now();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location: $location',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Date: ${DateFormat('dd-MM-yyyy').format(fileDate)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            tabs: const [
              Tab(text: 'Home'),
              Tab(text: 'Camera Roll'),
              Tab(text: 'Lock'),
            ],
          ),
          const SizedBox(height: 6), // Optional small spacing
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGalleryView(), // Home tab (will include slider inside)
                CameraRollTab(),
                LockTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSlider() {
    return SizedBox(
      height: 200, // Adjust height as needed
      child: PageView.builder(
        controller: _pageController,
        itemCount: mediaItems.length,
        physics: const PageScrollPhysics(), // ensures snapping behavior
        itemBuilder: (context, index) {
          final String path = mediaItems[index]['path'];
          final bool isAsset = mediaItems[index]['isAsset'] ?? false;
          final imageProvider = isAsset
              ? AssetImage(path) as ImageProvider
              : FileImage(File(path));

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    mediaList: mediaItems.map((f) => {
                      'path': f['path'],
                      'isAsset': f['isAsset'] ?? false,
                      'isVideo': f['path'].toString().endsWith('.mp4'),
                    }).toList(),
                    initialIndex: index,
                    userId: userId,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 3 / 2, // you can tweak this to your liking
                  child: Transform.scale(
                    scale: 1.05, // slight zoom effect
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.cover, // fill the box, but still controlled
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }



  Widget _buildGalleryView() {
    return Column(
        children: [
        _buildMonthSlider(), // Only shows in Home tab
    const SizedBox(height: 6),
    Expanded(
    child: GridView.builder(
    padding: const EdgeInsets.all(4),
        itemCount: mediaItems.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.8,
        ),
        itemBuilder: (context, index) {
          final media = mediaItems[index];
          final path = media['path'];
          final isVideo = media['isVideo'];
          final latitude = media['latitude'];
          final longitude = media['longitude'];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    mediaList: mediaItems,
                    initialIndex: index,
                    userId: userId,
                  ),
                ),
              );
            },
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: isVideo
                            ? Container(
                          color: Colors.black,
                          child: const Center(
                              child: Icon(Icons.play_circle, color: Colors.white)),
                        )
                            : Image.file(
                          File(path),
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (latitude != null && longitude != null)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.explore_outlined, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
    ],
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<Map<String, dynamic>> mediaList;
  final int initialIndex;
  final String userId;

  const FullScreenImageViewer({
    super.key,
    required this.mediaList,
    required this.initialIndex,
    required this.userId,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  int currentIndex = 0;
  String? locationName;
  String ? userId;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
    _getLocationNameForIndex(currentIndex);
  }

  void _getLocationNameForIndex(int index) async {
    final media = widget.mediaList[index];
    final lat = media['latitude'];
    final lon = media['longitude'];

    if (lat != null && lon != null) {
      try {
        final placemarks = await placemarkFromCoordinates(lat, lon);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          setState(() {
            locationName = [
              place.locality,
              place.subAdministrativeArea,
              place.administrativeArea,
              place.country
            ].where((s) => s != null && s.isNotEmpty).join(', ');
          });
        }
      } catch (e) {
        print("Error getting location name: $e");
        setState(() => locationName = null);
      }
    } else {
      setState(() => locationName = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaList.length,
            onPageChanged: (index) {
              setState(() {
                currentIndex = index;
                locationName = null; // Clear previous
              });
              _getLocationNameForIndex(index);
            },
            itemBuilder: (context, index) {
              final media = widget.mediaList[index];
              final isAsset = media['isAsset'] ?? false;
              final path = media['path'];

              return Center(
                child: isAsset
                    ? Image.asset(path, fit: BoxFit.contain)
                    : Image.file(File(path), fit: BoxFit.contain),
              );
            },
          ),

          // Top bar with icons
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) async {
                    if (value == 'share') {
                      // TODO: Share logic
                    } else if (value == 'delete') {
                      final media = widget.mediaList[currentIndex];
                      final mediaId = media['id'];

                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Delete Image"),
                          content: const Text("Are you sure you want to delete this image?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Delete", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final response = await http.delete(
                          Uri.parse("https://6ea8974672ed.ngrok-free.app/upload/$mediaId"),
                        );

                        if (response.statusCode == 200) {
                          setState(() {
                            widget.mediaList.removeAt(currentIndex);

                            if (widget.mediaList.isEmpty) {
                              Navigator.pop(context); // Exit if no media left
                            } else {
                              currentIndex = currentIndex.clamp(0, widget.mediaList.length - 1);
                              _pageController.jumpToPage(currentIndex);
                              _getLocationNameForIndex(currentIndex);
                            }
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("✅ Image deleted")),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("❌ Failed to delete image")),
                          );
                        }
                      }
                    } else if (value == 'post') {
                      final media = widget.mediaList[currentIndex];
                      final path = media['path'];

                      if (path != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CropScreen(file: XFile(path), userId: widget.userId),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Invalid media path.")),
                        );
                      }
                    }
                  },

                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'share', child: Text('Share')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    const PopupMenuItem(value: 'post', child: Text('Post')),
                  ],
                ),
              ],
            ),
          ),

          // Location Icon + name
          if (widget.mediaList[currentIndex]['latitude'] != null &&
              widget.mediaList[currentIndex]['longitude'] != null)
            Positioned(
              bottom: 40,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      final lat = widget.mediaList[currentIndex]['latitude'];
                      final lng = widget.mediaList[currentIndex]['longitude'];

                      if (lat != null && lng != null) {
                        final latitude = double.tryParse(lat.toString());
                        final longitude = double.tryParse(lng.toString());

                        if (latitude != null && longitude != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapScreen(
                                latitude: widget.mediaList[currentIndex]['latitude'],
                                longitude: widget.mediaList[currentIndex]['longitude'],
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Invalid coordinates.")),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("No location data found.")),
                        );
                      }
                    },
                    child: const Icon(Icons.explore_outlined, color: Colors.white, size: 30),
                  ),
                  if (locationName != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        locationName!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


class MediaTile extends StatelessWidget {
  final Map<String, dynamic> media;

  const MediaTile({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final path = media['path'];
    final isVideo = media['isVideo'];
    final latitude = media['latitude'];
    final longitude = media['longitude'];

    return Stack(
      children: [
        Positioned.fill(
          child: isVideo
              ? VideoPreviewWidget(path)
              : Image.file(File(path), fit: BoxFit.cover),
        ),
        if (latitude != null && longitude != null)
          Positioned(
            top: 8,
            right: 8,
            child: Icon(Icons.location_pin, color: Colors.redAccent),
          ),
      ],
    );
  }
}


class VideoPreviewWidget extends StatefulWidget {
  final String videoPath;

  const VideoPreviewWidget(this.videoPath, {super.key});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    )
        : const Center(child: CircularProgressIndicator());
  }
}

class CameraRollTab extends StatefulWidget {
  @override
  _CameraRollTabState createState() => _CameraRollTabState();
}

class _CameraRollTabState extends State<CameraRollTab> {
  List<AssetEntity> mediaList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGalleryMedia();
  }

  Future<void> _loadGalleryMedia() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      PhotoManager.openSetting();
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.all, // Includes images and videos
      hasAll: true,
    );

    if (albums.isNotEmpty) {
      final List<AssetEntity> media =
      await albums[0].getAssetListPaged(page: 0, size: 100);

      setState(() {
        mediaList = media;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (mediaList.isEmpty) {
      return const Center(child: Text("No media found"));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: mediaList.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (_, index) {
        return FutureBuilder<Uint8List?>(
          future: mediaList[index].thumbnailDataWithSize(
            const ThumbnailSize(200, 200),
          ),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return GestureDetector(
              onTap: () async {
                final file = await mediaList[index].file;
                final type = mediaList[index].type;
                print('Tapped on $type: ${file?.path}');
              },
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
              ),
            );
          },
        );
      },
    );
  }
}

class LockTab extends StatefulWidget {
  @override
  _LockTabState createState() => _LockTabState();
}

class _LockTabState extends State<LockTab> {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text("Lock Tab (Hidden with PIN/Pattern)"));
  }
}

class EditPostScreen extends StatelessWidget {
  final Map<String, dynamic> imageData;


  const EditPostScreen({super.key, required this.imageData});

  // Download Image Logic
  Future<void> _downloadImage(String path, BuildContext context) async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required.')),
      );
      return;
    }

    try {
      final mediaStore = MediaStore(); // ✅ Instance required

      await mediaStore.saveFile(
        tempFilePath: path,
        dirType: DirType.download,
        dirName: DirName.download, // Must be from DirName enum
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved to Downloads!')),
      );
    } catch (e) {
      print("Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save image.')),
      );
    }
  }

  // Post Image Logic
  Future<void> _postImage(String path, String caption, BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      final dio = Dio();
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(path, filename: 'upload.jpg'),
        'user_id': userId,
        'caption': caption,
      });

      final response = await dio.post(
        'https://2879ab6b712d.ngrok-free.app/api/posts/upload', // Your API
        data: formData,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posted successfully!')),
        );
        Navigator.pop(context); // Go back after success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post.')),
        );
      }
    } catch (e) {
      print("Post error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error while posting image.')),
      );
    }
  }

  // Caption Dialog
  void _showCaptionDialog(BuildContext context, String imagePath) {
    final TextEditingController captionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Caption'),
        content: TextField(
          controller: captionController,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Enter your caption here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _postImage(imagePath, captionController.text.trim(), context);
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  void _saveImageInApp(BuildContext context) async {
    // You can later store it in SQLite / SharedPrefs / Firebase / Local storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Image saved in app storage (mock).")),
    );

    // Optionally save to a specific folder or database
  }


  @override
  Widget build(BuildContext context) {
    final imagePath = imageData['path'];
    final isAsset = imageData['isAsset'] ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Edit Post"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'save') {
                _saveImageInApp(context); // Your function to save
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'save',
                  child: Text('Save in app'),
                ),
              ];
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: isAsset
                  ? Image.asset(imagePath, fit: BoxFit.contain)
                  : Image.file(File(imagePath), fit: BoxFit.contain),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Download Button
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () => _downloadImage(imagePath, context),
                ),

                // Share Button (optional: implement share logic)
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Add share functionality if needed
                  },
                  icon: const Icon(Icons.share),
                  label: const Text("Share"),
                ),

                // Post Button
                ElevatedButton(
                  onPressed: () => _showCaptionDialog(context, imagePath),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text("Post"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}