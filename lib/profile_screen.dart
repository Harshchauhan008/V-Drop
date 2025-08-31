// Make sure your imports are at the top
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotvibe/reels_screen.dart';
import 'package:spotvibe/setting&activity_screen.dart';
import 'package:video_player/video_player.dart';
import 'adding_infoscreen.dart';
//import 'addstoriesfrom_dates.dart';
import 'home_screen.dart';


class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const ProfileScreen({super.key, this.userProfile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final picker = ImagePicker();

  String? token, userId;
  String? name, username, email, bio, profilePic, pinnedImageUrl;
  int postCount = 0, followers = 0, following = 0;
  List<Map<String, String>> links = [];
  List<Map<String, String>> highlights = [];
  List<String> creatorTypes = [];

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    fetchHighlights();
  }

  Future<void> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getString('userId');

    if (token == null || userId == null) return;

    final response = await http.get(
      Uri.parse('https://f410765f9588.ngrok-free.app/api/user/profile/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final baseUrl = 'https://f410765f9588.ngrok-free.app';

      setState(() {
        name = data['name'];
        username = data['username'];
        email = data['email'];
        bio = data['bio'];

        profilePic = data['profile_image'] != null && data['profile_image'].toString().isNotEmpty
            ? '$baseUrl/uploads/profile_image/${data['profile_image']}'
            : null;

        pinnedImageUrl = data['pinnedImage'];
        postCount = data['postCount'] ?? 0;
        followers = data['followers'] ?? 0;
        following = data['following'] ?? 0;
        creatorTypes = List<String>.from(data['creatorTypes'] ?? []);
        links = List<Map<String, String>>.from(data['links'] ?? []);
      });
    }
  }


  void _editProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');
    if (token == null || userId == null) return;

    final response = await http.get(
      Uri.parse('https://f410765f9588.ngrok-free.app/api/user/profile/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final profileData = jsonDecode(response.body);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddInfoScreen(userProfile: profileData),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile data')),
      );
    }
  }

  Future<void> fetchHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('userId');
    if (userId == null) return;

    final url = Uri.parse('https://f410765f9588.ngrok-free.app/api/user/highlights/$userId');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        highlights = List<Map<String, String>>.from(data['highlights']);
      });
    }
  }

  Future<void> _uploadHighlightImage(File imageFile, String source, {DateTime? date}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId == null) return;

    final uri = Uri.parse('https://f410765f9588.ngrok-free.app/api/user/highlights/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['userId'] = userId
      ..fields['source'] = source;

    if (date != null) request.fields['date'] = date.toIso8601String();

    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) fetchHighlights();
  }

  void _showAddHighlightOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Add Highlight From",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _highlightOption(
                      icon: Icons.photo_library,
                      label: "Gallery",
                      onTap: () async {
                        Navigator.pop(context);
                        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          final image = File(pickedFile.path);
                          _uploadHighlightImage(image, "Gallery");
                        }
                      },
                    ),
                    _highlightOption(
                      icon: Icons.camera_alt,
                      label: "Camera",
                      onTap: () async {
                        Navigator.pop(context);
                        final pickedFile = await picker.pickImage(source: ImageSource.camera);
                        if (pickedFile != null) {
                          final image = File(pickedFile.path);
                          _uploadHighlightImage(image, "Camera");
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHighlightSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Your Highlights",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    itemCount: highlights.length + 1, // +1 for the 'Add' tile
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // First item: Add button with plus icon inside rounded square
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // close highlights dialog
                            _showAddHighlightOptions(context); // open add options dialog
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Center(
                              child: Icon(Icons.add, size: 30, color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      // Show highlight items
                      final highlight = highlights[index - 1];
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              highlight['image']!,
                              width: 60,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            highlight['title']!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
  }



  Widget _highlightOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade200,
            child: Icon(icon, size: 30, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget pinnedImageHeader() {
    return Container(
      height: 230,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        color: Colors.grey.shade200,
      ),
      child: pinnedImageUrl != null
          ? ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Image.network(
          pinnedImageUrl!,
          fit: BoxFit.cover,
        ),
      )
          : const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Pin a post to show here', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _statColumn(String title, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          username != null ? '@$username' : 'Tap to add username',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>  SettingsAndActivityScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                pinnedImageHeader(),
                Positioned(
                  left: 16,
                  bottom: -50,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: profilePic != null ? NetworkImage(profilePic!) : null,
                          child: profilePic == null
                              ? const Icon(Icons.person, size: 40, color: Colors.black)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name ?? 'Tap to add name',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 50),
                              IconButton(
                                icon: Image.asset('assets/images/Edit_Profile.png', height: 20),
                                onPressed: _editProfile,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _statColumn('Posts', postCount),
                              _statColumn('Followers', followers),
                              _statColumn('Following', following),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 70),

            if (creatorTypes.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: creatorTypes.map((type) => Chip(label: Text(type))).toList(),
              ),

            if (bio != null && bio!.trim().isNotEmpty) _infoRow(bio!),
            if (bio == null || bio!.trim().isEmpty) _infoRow("Bio: Tap to add bio"),

            if (links.isNotEmpty)
              _infoRow(
                links.map((e) => e['url']).whereType<String>().join(', '),
              ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Highlights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    onPressed: () => _showHighlightSourceDialog(context),
                    child: const Text('+ Add Moments',
                      style:TextStyle(fontFamily: 'HomemadeApple',
                          color: Colors.blueGrey ) ,),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (highlights.isEmpty)
                    GestureDetector(
                      onTap: () => _showAddHighlightOptions(context),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 70,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: const Icon(Icons.add, size: 30, color: Colors.grey),
                      ),
                    ),
                  for (var item in highlights)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              item['image']!,
                              width: 70,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['title']!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            DefaultTabController(
              length: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TabBar(
                    indicatorColor: Colors.black,
                    tabs: [
                      Tab(icon: Icon(Icons.photo)),           // Photos
                      Tab(icon: Icon(Icons.grid_on)),         // Grid
                      Tab(icon: Icon(Icons.video_library)),   // Reels
                      Tab(icon: Icon(Icons.person_pin)),      // Tagged
                    ],
                  ),
                  // This height makes it scrollable inside SingleChildScrollView
                  Container(
                    height: MediaQuery.of(context).size.height * 0.6, // or any value you prefer
                    child: const TabBarView(
                      children: [
                        PostsGrid(filter: 'image'),
                        PostsGrid(), // all posts
                        PostsGrid(filter: 'reel'),
                        TaggedPostsGrid(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaggedPostsGrid extends StatefulWidget {
  const TaggedPostsGrid({super.key});

  @override
  State<TaggedPostsGrid> createState() => _TaggedPostsGridState();
}

class _TaggedPostsGridState extends State<TaggedPostsGrid> {
  List<MediaItem> taggedPosts = [];

  @override
  void initState() {
    super.initState();
    fetchTagged();
  }

  Future<void> fetchTagged() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    final uri = Uri.parse('https://f410765f9588.ngrok-free.app/api/user/tagged/$userId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<MediaItem> items = List<Map<String, dynamic>>.from(data['posts'] ?? [])
          .map((item) => MediaItem.fromJson(item))
          .toList();

      setState(() {
        taggedPosts = items;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: taggedPosts.length,
      itemBuilder: (context, index) {
        final item = taggedPosts[index];

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item.url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        );
      },
    );
  }
}
class PostsGrid extends StatefulWidget {
  final String? filter; // image, reel, or null for all

  const PostsGrid({super.key, this.filter});

  @override
  State<PostsGrid> createState() => _PostsGridState();
}

class _PostsGridState extends State<PostsGrid> {
  List<MediaItem> posts = [];
  Set<String> pinnedPostIds = {}; // Store pinned posts by their IDs

  @override
  void initState() {
    super.initState();
    loadPinnedPosts();
    fetchPosts();
  }

  Future<void> loadPinnedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = prefs.getStringList('pinnedPosts') ?? [];
    setState(() {
      pinnedPostIds = pinned.toSet();
    });
  }

  Future<void> savePinnedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinnedPosts', pinnedPostIds.toList());
  }

  Future<void> fetchPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    final uri = Uri.parse(
      'https://f410765f9588.ngrok-free.app/api/user/posts/$userId${widget.filter != null ? "?filter=${widget.filter}" : ""}',
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final List<MediaItem> items = List<Map<String, dynamic>>.from(data['posts'] ?? [])
            .map((item) => MediaItem.fromJson(item))
            .toList();

        setState(() {
          if (widget.filter == 'image') {
            posts = items.where((item) => item.mediaType == 'image' && !item.isVideo).toList();
          } else if (widget.filter == 'reel') {
            posts = items.where((item) => item.mediaType == 'video' && item.isVideo).toList();
          } else {
            posts = items;
          }
        });
      } else {
        print('Failed to fetch posts: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching posts: $e');
    }
  }


  void togglePin(MediaItem item) {
    setState(() {
      if (pinnedPostIds.contains(item.id)) {
        pinnedPostIds.remove(item.id);
      } else {
        pinnedPostIds.add(item.id);
      }
    });
    savePinnedPosts();
  }

  void showPinDialog(MediaItem item) {
    final isPinned = pinnedPostIds.contains(item.id);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isPinned ? 'Unpin this post?' : 'Pin this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                togglePin(item);
                Navigator.pop(context);
              },
              child: Text(isPinned ? 'Unpin' : 'Pin'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinnedPosts = posts.where((post) => pinnedPostIds.contains(post.id)).toList();

    return Column(
      children: [
        // Pinned posts slider (if any)
        if (pinnedPosts.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: pinnedPosts.length,
              itemBuilder: (context, index) {
                final item = pinnedPosts[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.isVideo
                            ? VideoPlayerWidget(videoUrl: item.url)
                            : Image.network(
                          item.url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => togglePin(item), // Unpin from slider
                          child: const Icon(
                            Icons.push_pin,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Main grid (reels or images)
        Expanded(
          child: widget.filter == 'reel'
              ? GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final item = posts[index];

              return Stack(
                children: [
                  GestureDetector(
                    onLongPress: () => showPinDialog(item), // Long press to pin/unpin
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReelScreen(
                            reels: posts,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: VideoPlayerWidget(videoUrl: item.url),
                    ),
                  ),
                  // Show pin icon ONLY if pinned
                  if (pinnedPostIds.contains(item.id))
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.push_pin,
                        color: Colors.redAccent,
                      ),
                    ),
                ],
              );
            },
          )
              :SizedBox(
    height: MediaQuery.of(context).size.height * 0.6, // Adjust as needed
    child: MasonryGridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final item = posts[index];

              // Only show images (ignore videos)
              if (item.isVideo) return const SizedBox.shrink();

              // Create a pattern of big tiles (like Instagram explore)
              final isBig = widget.filter == 'image'
                  ? index == 0 || index == 4
                  : index == 0 || index == 2;
              return GestureDetector(
                onLongPress: () => showPinDialog(item),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final userId = prefs.getString('userId') ?? '';
                  final postMap = item.toPostCardMap(currentUserId: userId);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.white,
                        appBar: AppBar(title: const Text("Post")),
                        body: SingleChildScrollView(
                          child: PostCard(postData: item),
                        ),
                      ),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        item.url,
                        height: isBig ? 260 : 127, // Dynamic height for variety
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                    if (pinnedPostIds.contains(item.id))
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.push_pin,
                          color: Colors.redAccent,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        ),
      ],
    );
  }
}
class MediaItem {
  final String id;
  final String mediaType; // 'image' or 'video'
  final String url;
  final bool isVideo;
  final bool isPinned;
  final String caption;
  final String uploaderId;
  final String? thumbnailUrl;
  final List<String> taggedPeople;
  final String? location;
  final String? profilePic;
  final String? userName;
  final List<String> likedByProfiles;
  final int likeCount;
  final int commentCount;
  final double? latitude;
  final double? longitude;

  MediaItem({
    required this.id,
    required this.mediaType,
    required this.url,
    this.isVideo = false,
    this.isPinned = false,
    this.caption = '',
    required this.uploaderId,
    this.thumbnailUrl,
    required this.taggedPeople,
    this.location,
    this.profilePic,
    this.userName,
    this.likedByProfiles = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.latitude,
    this.longitude,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final baseUrl = "https://f410765f9588.ngrok-free.app";
    final rawProfilePic = json['user']?['profile_image'];

    return MediaItem(
      id: json['post_id'].toString(),
      mediaType: json['media_type'] ?? 'image',
      url: "$baseUrl${json['media_url']}",
      isVideo: (json['media_type'] ?? 'image') == 'video',
      isPinned: false,
      caption: json['caption'] ?? '',
      uploaderId: json['user_id'].toString(),
      thumbnailUrl: null,
      taggedPeople: [], // Update if backend returns this
      location: json['location_name'],
      userName: json['user']?['username'],
      profilePic: rawProfilePic != null && rawProfilePic.toString().isNotEmpty
          ? "$baseUrl/uploads/profile_image/$rawProfilePic"
          : null,
      likedByProfiles: [], // Update if backend returns this
      likeCount: 0,
      commentCount: 0,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaType': mediaType,
      'media_url': url,
      'isVideo': isVideo,
      'isPinned': isPinned,
      'caption': caption,
      'uploaderId': uploaderId,
      'thumbnailUrl': thumbnailUrl,
      'taggedPeople': taggedPeople,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Map<String, dynamic> toPostCardMap({required String currentUserId}) {
    return {
      'postId': id,
      'postUrl': url,
      'isVideo': isVideo,
      'isPinned': isPinned,
      'caption': caption,
      'uploaderId': uploaderId,
      'isLiked': false,
      'likes': [],
      'comments': [],
      'currentUserId': currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  MediaItem copyWith({
    String? id,
    String? mediaType,
    String? url,
    bool? isVideo,
    bool? isPinned,
    String? caption,
    String? uploaderId,
    String? thumbnailUrl,
    List<String>? taggedPeople,
    String? location,
    String? profilePic,
    String? userName,
    List<String>? likedByProfiles,
    int? likeCount,
    int? commentCount,
    double? latitude,
    double? longitude,
  }) {
    return MediaItem(
      id: id ?? this.id,
      mediaType: mediaType ?? this.mediaType,
      url: url ?? this.url,
      isVideo: isVideo ?? this.isVideo,
      isPinned: isPinned ?? this.isPinned,
      caption: caption ?? this.caption,
      uploaderId: uploaderId ?? this.uploaderId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      taggedPeople: taggedPeople ?? this.taggedPeople,
      location: location ?? this.location,
      profilePic: profilePic ?? this.profilePic,
      userName: userName ?? this.userName,
      likedByProfiles: likedByProfiles ?? this.likedByProfiles,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}



class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.setVolume(0);
        _controller.play(); // Autoplay the video
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
        ? Stack(
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        const Positioned(
          top: 4,
          right: 4,
          child: Icon(Icons.videocam, color: Colors.white, size: 16),
        ),
      ],
    )
        : const Center(child: CircularProgressIndicator());
  }
}


