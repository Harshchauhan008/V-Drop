// drop_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart'; // You must import this if using preview
import 'package:shared_preferences/shared_preferences.dart';
import 'drop_camera.dart';

class DropScreen extends StatefulWidget {
  final File? capturedImage;

  const DropScreen({Key? key, this.capturedImage}) : super(key: key);

  @override
  State<DropScreen> createState() => _DropScreenState();
}

class _DropScreenState extends State<DropScreen> {
  LatLng? currentLatLng;
  MapController _mapController = MapController();
  String? postType;
  String privacy = 'Public';
  bool allowComments = true;
  bool allowLikes = true;
  bool showProfile = true;
  TextEditingController captionController = TextEditingController();
  File? capturedImage;
  late String userId;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
    _loadUserId(); // ✅ Add this
    if (widget.capturedImage != null) {
      capturedImage = widget.capturedImage;
      postType = 'captured';
    }
  }


  Future<void> _fetchCurrentLocation() async {
    if (currentLatLng != null) {
      setState(() => currentLatLng = null);
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final latLng = LatLng(position.latitude, position.longitude);

    setState(() {
      currentLatLng = latLng;
    });

    _mapController.move(latLng, 16);
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedUserId = prefs.getString('userId');

    if (storedUserId == null) {
      print('User not logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID not found. Please login again.")),
      );
      // Optionally navigate to login page here
    } else {
      setState(() {
        userId = storedUserId;
      });
      print('✅ User ID loaded: $userId');
    }
  }


  void _togglePrivacy() {
    setState(() {
      privacy = (privacy == 'Public') ? 'Private' : 'Public';
    });
  }

  void _setPostType(String type) {
    setState(() => postType = type);
  }

  Future<void> _uploadPost() async {
    if (currentLatLng == null || postType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please set location and choose post type")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // ✅ match login screen

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://f410765f9588.ngrok-free.app/api/drop-post'),
    );

    // ✅ Add Authorization header
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['caption'] = captionController.text;
    request.fields['type'] = postType!;
    request.fields['privacy'] = privacy;
    request.fields['allowLikes'] = allowLikes.toString();
    request.fields['allowComments'] = allowComments.toString();
    request.fields['latitude'] = currentLatLng!.latitude.toString();
    request.fields['longitude'] = currentLatLng!.longitude.toString();
    request.fields['showProfile'] = showProfile.toString();
    request.fields['dropRadius'] = '100';

    if (capturedImage != null) {
      final mimeTypeData = lookupMimeType(capturedImage!.path)?.split('/');
      if (mimeTypeData != null) {
        final file = await http.MultipartFile.fromPath(
          'file',
          capturedImage!.path,
          contentType: MediaType(mimeTypeData[0], mimeTypeData[1]),
        );
        request.files.add(file);
      }
    }

    final response = await request.send();

    if (response.statusCode == 201 || response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post uploaded successfully!")),
      );
      Navigator.pop(context);
    } else {
      final respStr = await response.stream.bytesToString();
      debugPrint('❌ Upload failed: $respStr'); // Helpful for debugging
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to upload post")),
      );
    }
  }


  void _openCameraAndPreview() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DropCamera()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Drop Post", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MyDropPostsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentLatLng ?? LatLng(20.5937, 78.9629),
              initialZoom: currentLatLng != null ? 16 : 4,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.spotvibes',
              ),
              if (currentLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLatLng!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  ],
                ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(245),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (capturedImage != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(capturedImage!, height: 150),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.camera_alt,
                            color: postType == 'captured' ? Colors.deepPurple : Colors.teal,
                          ),
                          onPressed: _openCameraAndPreview,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.text_fields,
                            color: postType == 'text' ? Colors.deepPurple : Colors.teal,
                          ),
                          onPressed: () => _setPostType('text'),
                        ),
                      ],
                    ),
                    TextField(
                      controller: captionController,
                      decoration: const InputDecoration(
                        hintText: "Enter caption...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: Icon(
                            Icons.my_location,
                            color: currentLatLng != null ? Colors.redAccent : Colors.grey,
                          ),
                          label: const Text("Set Location"),
                          onPressed: _fetchCurrentLocation,
                        ),
                      ],
                    ),
                    SwitchListTile(
                      value: privacy == 'Public',
                      onChanged: (_) => _togglePrivacy(),
                      title: Text("Privacy: $privacy"),
                      activeColor: Colors.deepPurple,
                    ),
                    SwitchListTile(
                      value: showProfile,
                      onChanged: (val) => setState(() => showProfile = val),
                      title: const Text("Show Name & Profile on Post"),
                      activeColor: Colors.deepPurple,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: allowLikes,
                              onChanged: (val) => setState(() => allowLikes = val!),
                            ),
                            const Text("Allow Likes"),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: allowComments,
                              onChanged: (val) => setState(() => allowComments = val!),
                            ),
                            const Text("Allow Comments"),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _uploadPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text("Upload Post", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class MyDropPostsScreen extends StatefulWidget {
  @override
  _MyDropPostsScreenState createState() => _MyDropPostsScreenState();
}

class _MyDropPostsScreenState extends State<MyDropPostsScreen> {
  List<dynamic> posts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchMyPosts();
  }

  Future<void> fetchMyPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    final response = await http.get(
      Uri.parse('https://f410765f9588.ngrok-free.app/api/drop/user/my-posts'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        posts = data['data'];
        loading = false;
      });
    } else {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch posts")),
      );
    }
  }

  Future<void> deletePost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');

    final response = await http.delete(
      Uri.parse('https://f410765f9588.ngrok-free.app/api/drop/delete-drop-post/$postId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post deleted")),
      );
      fetchMyPosts(); // refresh the list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete post")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Drops")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
          ? const Center(child: Text("No posts found"))
          : ListView.builder(
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return Card(
            margin: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              title: Text(post['caption'] ?? 'No caption'),
              subtitle: Text("Type: ${post['type']} | Privacy: ${post['privacy']}"),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => deletePost(post['id']),
              ),
            ),
          );
        },
      ),
    );
  }
}