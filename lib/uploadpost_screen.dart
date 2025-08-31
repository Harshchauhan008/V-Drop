import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class PostScreen extends StatefulWidget {
  final String userId;

  const PostScreen({super.key, required this.userId});
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {

  List<AssetEntity> deviceMedia = [];
  List<XFile> inAppSelectedMedia = [];
  XFile? selectedMedia;
  Set<String> selectedMediaPaths = {};
  bool isDeviceGallery = true;
  VideoPlayerController? _videoController;

  final TextEditingController captionController = TextEditingController();
  String? taggedLocation;
  double latitude = 0.0;
  double longitude = 0.0;
  List<dynamic> posts = [];


  @override
  void initState() {
    super.initState();
    _loadDeviceMedia();
  }


  Future<void> uploadPost() async {
    if (selectedMedia == null) {
      print("❌ No media selected");
      return;
    }

    final isVideo = selectedMedia!.path.toLowerCase().endsWith('.mp4');
    final endpoint = isVideo ? '/reels' : '/posts';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://f410765f9588.ngrok-free.app$endpoint'),
    );

    request.fields['user_id'] = widget.userId;
    request.fields['caption'] = captionController.text;
    request.fields['location'] = taggedLocation ?? '';
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();

    request.files.add(
      await http.MultipartFile.fromPath(
        isVideo ? 'video' : 'image',
        selectedMedia!.path,
      ),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final resBody = await response.stream.bytesToString();
      final jsonData = jsonDecode(resBody);

      setState(() {
        posts.insert(0, jsonData['post']);
      });

      Navigator.pop(context);
    } else {
      print("❌ Upload failed: ${response.statusCode}");
    }
  }

  Future<void> _loadDeviceMedia() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;

    if (!permission.hasAccess) {
      // Ask user to grant full access
      PhotoManager.openSetting();
      return;
    }

    final filter = FilterOptionGroup(
      imageOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      videoOption: const FilterOption(
        durationConstraint: DurationConstraint(min: Duration.zero),
      ),
      orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: filter,
    );

    if (albums.isNotEmpty) {
      final recentAlbum = albums.first;
      final media = await recentAlbum.getAssetListPaged(page: 0, size: 500);

      setState(() {
        deviceMedia = media;
      });

      if (media.isNotEmpty) {
        final file = await media.first.file;
        if (file != null) {
          _setSelectedMedia(XFile(file.path));
        }
      }
    }
  }

  void _pickInAppMedia() async {
    final picker = ImagePicker();
    final List<XFile> picked = [];

    final List<XFile>? images = await picker.pickMultiImage();
    if (images != null) picked.addAll(images);

    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) picked.add(video);

    if (picked.isNotEmpty) {
      setState(() {
        inAppSelectedMedia = picked;
      });
      _setSelectedMedia(picked.first);
    }
  }

  void _setSelectedMedia(XFile file) {
    setState(() {
      if (selectedMediaPaths.contains(file.path)) {
        selectedMediaPaths.remove(file.path);
        if (selectedMedia?.path == file.path) {
          selectedMedia = null;
        }
      } else {
        selectedMediaPaths.add(file.path);
        selectedMedia = file;
      }

      if (file.path.toLowerCase().endsWith(".mp4")) {
        _videoController?.dispose();
        _videoController = VideoPlayerController.file(File(file.path))
          ..initialize().then((_) {
            setState(() {});
            _videoController?.play();
          });
      }
    });
  }

  Widget _buildMediaGallery() {
    List<Widget> mediaTiles;

    if (isDeviceGallery) {
      mediaTiles = deviceMedia.map((asset) {
        return FutureBuilder<Uint8List?>(
          future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
          builder: (_, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            return GestureDetector(
              onTap: () async {
                final file = await asset.file;
                if (file != null) {
                  setState(() {
                    if (selectedMediaPaths.contains(file.path)) {
                      selectedMediaPaths.remove(file.path);
                      inAppSelectedMedia.removeWhere((x) => x.path == file.path);
                    } else {
                      selectedMediaPaths.add(file.path);
                      inAppSelectedMedia.add(XFile(file.path));
                    }
                    selectedMedia = inAppSelectedMedia.isNotEmpty ? inAppSelectedMedia.first : null;
                  });
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: selectedMediaPaths.contains(asset.relativePath)
                          ? Border.all(color: Colors.blue, width: 3)
                          : null,
                    ),
                    child: Image.memory(snapshot.data!, fit: BoxFit.cover),
                  ),
                  if (selectedMediaPaths.contains(asset.relativePath))
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.check_circle, color: Colors.blue, size: 24),
                    ),
                  if (asset.type == AssetType.video)
                    const Align(
                      alignment: Alignment.center,
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white, size: 30),
                    ),
                ],
              ),
            );
          },
        );
      }).toList();
    } else {
      mediaTiles = inAppSelectedMedia.map((file) {
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selectedMediaPaths.contains(file.path)) {
                selectedMediaPaths.remove(file.path);
                inAppSelectedMedia.removeWhere((x) => x.path == file.path);
              } else {
                selectedMediaPaths.add(file.path);
                inAppSelectedMedia.add(file);
              }
              selectedMedia = inAppSelectedMedia.isNotEmpty ? inAppSelectedMedia.first : null;
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: selectedMediaPaths.contains(file.path)
                      ? Border.all(color: Colors.blue, width: 3)
                      : null,
                ),
                child: Image.file(File(file.path), fit: BoxFit.cover),
              ),
              if (selectedMediaPaths.contains(file.path))
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.check_circle, color: Colors.blue, size: 24),
                ),
            ],
          ),
        );
      }).toList();
    }

    return GridView.count(
      padding: const EdgeInsets.all(4),
      crossAxisCount: 3,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: mediaTiles,
    );
  }

  Widget _buildGallerySwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () {
              setState(() {
                isDeviceGallery = false;
              });
              _pickInAppMedia();
            },
            child: Text(
              "In-App Gallery",
              style: TextStyle(
                color: !isDeviceGallery ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                isDeviceGallery = true;
              });
              _loadDeviceMedia();
            },
            child: Text(
              "Device Gallery",
              style: TextStyle(
                color: isDeviceGallery ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Post', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              if (selectedMedia != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CropScreen(
                      file: selectedMedia!,
                      userId: widget.userId, // Replace with actual user ID
                    ),
                  ),
                );

              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select a media first.")),
                );
              }
            },
            child: const Text(
              "Next",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],

      ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildGallerySwitcher(),
            _buildMediaGallery(),
            const SizedBox(height: 16),
          ],
        ),
    );
  }
}

class CropScreen extends StatefulWidget {
  final XFile file;
  final String? locationName;
  final double? lat;
  final double? lng;
  final String userId;

  const CropScreen({
    super.key,
    required this.userId,
    required this.file,
    this.locationName,
    this.lat,
    this.lng,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final CropController _cropController = CropController();
  VideoPlayerController? _videoController;
  File? mediaFile;
  final TextEditingController captionController = TextEditingController();
  final TextEditingController musicNameController = TextEditingController();
  String? taggedLocation;
  double? lat;
  double? lng;

  Uint8List? _croppedImage;
  bool _isCropped = false;

  String? _selectedMusic;
  String? _caption;

  late final String? latitude;
  late final String? longitude;


  @override
  void initState() {
    super.initState();
    mediaFile = File(widget.file.path); // ✅ This is missing
    if (_isVideo(widget.file.path)) {
      _videoController = VideoPlayerController.file(mediaFile!)
        ..initialize().then((_) => setState(() {}))
        ..setLooping(true)
        ..play();
    }
    taggedLocation = widget.locationName;
    lat = widget.lat;
    lng = widget.lng;
  }


  bool _isVideo(String path) => path.endsWith(".mp4") || path.endsWith(".mov");

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _showCaptionDialog() {
    TextEditingController _captionController = TextEditingController(text: _caption ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Add Caption"),
        content: TextField(
          controller: _captionController,
          decoration: InputDecoration(hintText: "Write a caption..."),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text("Save"),
            onPressed: () {
              setState(() => _caption = _captionController.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _selectMusic() async {
    List<String> musicList = ["Acoustic Vibe", "Chill Beat", "Epic Sound"];
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        children: musicList
            .map((track) => ListTile(
          leading: Icon(Icons.music_note),
          title: Text(track),
          onTap: () {
            setState(() => _selectedMusic = track);
            Navigator.pop(context);
          },
        ))
            .toList(),
      ),
    );
  }

  Future<void> _postContent(File file, String caption, String? musicName) async {
    final isVideo = file.path.endsWith(".mp4") || file.path.endsWith(".mov");
    final uri = isVideo
        ? Uri.parse('https://f410765f9588.ngrok-free.app/api/upload/reel')
        : Uri.parse('https://f410765f9588.ngrok-free.app/api/upload');

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId'); // ✅ this matches what you're using elsewhere

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("User not logged in. Please log in again."),
      ));
      return;
    }

    var request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath(isVideo ? 'video' : 'image', file.path))
      ..fields['caption'] = caption
      ..fields['user_id'] = userId; // ✅ send correct user ID

    if (musicName != null) request.fields['music_title'] = musicName;
    if (taggedLocation != null) request.fields['location'] = taggedLocation!;
    if (lat != null) request.fields['latitude'] = lat.toString();
    if (lng != null) request.fields['longitude'] = lng.toString();

    final response = await request.send();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Post uploaded successfully!"),
      ));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Upload failed. Try again."),
      ));
    }
  }


  Future<Map<String, String>?> _showLocationSearchDialog(BuildContext context) async {
    TextEditingController searchController = TextEditingController();
    List<Map<String, String>> suggestions = [];
    bool isLoading = false;
    Timer? _debounce;

    return await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _getSuggestions(String query) async {
              if (query.trim().isEmpty) return;

              setState(() {
                isLoading = true;
                suggestions = [];
              });

              try {
                final url = Uri.parse(
                    'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=10');

                final res = await http.get(
                  url,
                  headers: {
                    'User-Agent': 'com.example.spotvibes', // Required
                  },
                );

                if (res.statusCode == 200) {
                  final List data = jsonDecode(res.body);
                  setState(() {
                    suggestions = data.map<Map<String, String>>((item) {
                      return {
                        'display': item['display_name'],
                        'lat': item['lat'],
                        'lon': item['lon'],
                      };
                    }).toList();
                    isLoading = false;
                  });
                } else {
                  print("❌ Failed with status code: ${res.statusCode}");
                  setState(() => isLoading = false);
                }
              } catch (e) {
                print("⚠️ Error fetching suggestions: $e");
                setState(() => isLoading = false);
              }
            }

            void _onSearchChanged(String query) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                _getSuggestions(query);
              });
            }

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text("Search Location", style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                // Adjust height to fit max suggestions cleanly
                height: 300,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Enter location...",
                        hintStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: isLoading
                          ? Center(child: CircularProgressIndicator(color: Colors.white))
                          : suggestions.isEmpty && searchController.text.isNotEmpty
                          ? Center(child: Text("No results found", style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final s = suggestions[index];
                          return ListTile(
                            title: Text(s['display'] ?? '', style: TextStyle(color: Colors.white)),
                            onTap: () => Navigator.pop(context, s),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleTagLocation() async {
    final selectedLocation = await _showLocationSearchDialog(context);
    if (selectedLocation != null) {
      setState(() {
        taggedLocation = selectedLocation['display'];
        lat = double.tryParse(selectedLocation['lat']!);
        lng = double.tryParse(selectedLocation['lon']!);
      });
    }
  }


  Widget _buildEditOverlay() {
    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_selectedMusic != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note, color: Colors.white),
                Text(_selectedMusic!,
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          const SizedBox(height: 8),
          IconButton(
            icon: Icon(Icons.crop, color: Colors.white),
            onPressed: () => setState(() => _isCropped = false),
          ),
          IconButton(
            icon: Icon(Icons.music_note, color: Colors.white),
            onPressed: _selectMusic,
          ),
          IconButton(
            icon: Icon(Icons.tag, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("Tag people - Coming Soon!")));
            },
          ),
          ElevatedButton(
            onPressed: _handleTagLocation,
            child: Text(taggedLocation ?? "Tag Location"),
          ),


          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: _showCaptionDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildBackArrow(){
    return Positioned(
      top: 20,
        left: 10,
        child: IconButton(onPressed: (){
          Navigator.pop(context);
        }, icon: Icon(Icons.arrow_back, color: Colors.white,)),
    );
  }

  bool _isCaptionExpanded = false; // Define this in your State class

  Widget _buildBottomActionBar() {
    return Positioned(
      bottom: 20,
      left: 10,
      right: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_caption != null && _caption!.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final maxLines = _isCaptionExpanded ? null : 2;
                final textSpan = TextSpan(
                  text: _caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                );
                final textPainter = TextPainter(
                  text: textSpan,
                  maxLines: maxLines,
                  textDirection: TextDirection.ltr,
                )..layout(maxWidth: constraints.maxWidth);

                final isOverflowing = textPainter.didExceedMaxLines;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _caption!,
                      maxLines: _isCaptionExpanded ? null : 2,
                      overflow: TextOverflow.fade,
                      softWrap: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    if (isOverflowing && !_isCaptionExpanded)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCaptionExpanded = true;
                          });
                        },
                        child: const Text(
                          "More",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 8),
          Row(
           // mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  // TODO: Add more logic
                },
                child: const Text('Add more'),
              ),
              SizedBox(width: 100,),
              ElevatedButton(
                onPressed: () {
                  if (mediaFile != null) {
                    _postContent(
                      mediaFile!,
                      captionController.text.trim().isEmpty
                          ? (_caption ?? '')
                          : captionController.text.trim(),
                      musicNameController.text.trim().isEmpty
                          ? _selectedMusic
                          : musicNameController.text.trim(),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("No media selected."),
                    ));
                  }
                },
                child: const Text("Post"),
              ),

              SizedBox(width: 20,),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("More options - Coming Soon!")));
                },
                child: const Icon(Icons.more_horiz),
              ),
            ],
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    bool isVideo = _isVideo(widget.file.path);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (!_isCropped)
              isVideo
                  ? Center(
                child: _videoController != null &&
                    _videoController!.value.isInitialized
                    ? AspectRatio(
                  aspectRatio:
                  _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
                    : CircularProgressIndicator(),
              )
                  : FutureBuilder<Uint8List>(
                future: widget.file.readAsBytes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  return Crop(
                    controller: _cropController,
                    image: snapshot.data!,
                    onCropped: (cropped) {
                      setState(() {
                        _croppedImage = cropped;
                        _isCropped = true;
                      });
                    },
                    baseColor: Colors.black,
                    maskColor: Colors.black.withAlpha(100),
                    withCircleUi: false,
                    interactive: true,
                  );
                },
              ),
            if (_isCropped && _croppedImage != null)
              Center(
                child: Image.memory(_croppedImage!),
              ),
            if (_isCropped && !isVideo) _buildEditOverlay(),
            if (_isCropped) _buildBottomActionBar(),
            if (_isCropped) _buildBackArrow(),
          ],
        ),
      ),
      appBar: !_isCropped
          ? AppBar(
        title: const Text("Crop Media"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!isVideo)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => _cropController.crop(),
            ),
        ],
      )
          : null,
    );
  }
}