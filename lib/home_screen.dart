import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotvibe/camera_screen.dart';
import 'package:spotvibe/profile_screen.dart';
import 'package:spotvibe/reels_screen.dart';
import 'package:spotvibe/suggestuser_screen.dart';
import 'package:spotvibe/uploadpost_screen.dart';

import 'map_screen.dart';
import 'messagescreen.dart';
import 'other_users.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userId;
  String? userProfilePic;
  List<Map<String, dynamic>> friendStories = [];
  List<MediaItem> posts = [];


  // posts feed
  List<Map<String, dynamic>> suggestions = [];// user suggestions


  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserId();
  }


  Future<void> _loadData() async {
    await fetchUserData();
    await fetchFriendStories();
    await fetchPosts(); // loads posts from server
    await fetchSuggestions();
  }
  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  Future<void> fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final token = prefs.getString('token'); // Get the auth token

    if (userId == null || token == null) return;

    final baseUrl = 'https://f410765f9588.ngrok-free.app';
    final imageBaseUrl = '$baseUrl/uploads/profile_image/';

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/user/profile/$userId'), // ✅ Corrected endpoint
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        final profileImageName = data['profile_image'];

        setState(() {
          userProfilePic = (profileImageName != null && profileImageName.toString().isNotEmpty)
              ? imageBaseUrl + profileImageName
              : null;
        });
      } else {
        print('Failed to load user data. Status: ${res.statusCode}');
        print('Response body: ${res.body}');
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }




  Future<void> fetchFriendStories() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    final url =
    Uri.parse('https://f410765f9588.ngrok-free.app/api/story/friends/$userId');
    final res = await http.get(url);
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      setState(() {
        friendStories = data.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> fetchPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    final response = await http.get(Uri.parse('https://f410765f9588.ngrok-free.app/api/posts/feed/$userId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print('Fetched posts: $data');

      setState(() {
        posts = data.map<MediaItem>((item) => MediaItem.fromJson(item)).toList();
      });
    } else {
      print('Failed to fetch posts: ${response.statusCode}');
    }
  }


  Future<void> fetchSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final url = Uri.parse('https://f410765f9588.ngrok-free.app/api/users/suggestions/$userId');

    final res = await http.get(url);
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      setState(() {
        suggestions = List<Map<String, dynamic>>.from(data);
      });
    } else {
      print('Failed to load suggestions: ${res.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPostsFromServer() async {
    final url = Uri.parse('https://f410765f9588.ngrok-free.app/api/posts'); // 🔁 Replace with your API endpoint
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load posts');
    }
  }

  void openCamera() {}
  void openUploadPost() {}
  void openGallery() {}
  void openChatScreen() {
    Navigator.pushNamed(context, '/chat');
  }

  DecorationImage? buildImage(String? url) {
    if (url != null && url.isNotEmpty) {
      return DecorationImage(
        image: NetworkImage(url),
        fit: BoxFit.cover,
      );
    }
    return null;
  }


  Widget _buildStoryCard({
    required String imageUrl,
    required String username,
    required Widget centerWidget,
    bool isPlaceholder = false,
    String? profileImage, // Add this for friend profile picture
  }) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Main image container
              Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue, width: 2),
                  image: buildImage(imageUrl),
                  color: Colors.grey[300],
                ),
                child: isPlaceholder
                    ? (profileImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    userProfilePic!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.error),
                  ),
                )
                    : const Icon(Icons.person, size: 40))
                    : null,
              ),

              // Concave bottom bar + profile circle
              Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    // Cut out dip or profile image
                    Positioned(
                      top: -12,
                      child: isPlaceholder
                          ? Image.asset(
                        'assets/images/Green_Cplus.png',
                        height: 30,
                      )
                          : Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: profileImage != null
                              ? DecorationImage(
                            image: NetworkImage(profileImage),
                            fit: BoxFit.cover,
                          )
                              : null,
                          color: Colors.grey[400],
                        ),
                        child: profileImage == null
                            ? const Icon(Icons.person, size: 16, color: Colors.black)
                            : null,
                      ),
                    ),

                    // Black concave container
                    ClipPath(
                      clipper: ConcaveTopClipper(),
                      child: Container(
                        width: 117,
                        height: 50,
                        color: Colors.black.withAlpha(152),
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: centerWidget,
                        ),
                      ),
                    ),
                  ],
                ),
              Text(
                username,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
      final reels = posts.where((p) => p.mediaType == 'reel').toList();
      final postFeed = posts.where((p) => p.mediaType == 'post').toList();
      return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 60,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.pink, Colors.purple],
          ).createShader(bounds),
          child: const Text(
            'Spotvibe',
            style: TextStyle(
              fontFamily: 'HomemadeApple',
              fontSize: 28,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.message, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen()),
              );
            },
          ),
        ],
      ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- STORIES ----------
              Container(
                height: 180,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child:ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: friendStories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // 🔹 YOUR STORY
                      return _buildStoryCard(
                        imageUrl: '', // no thumbnail
                        username: 'Your Story',
                        centerWidget: const Icon(Icons.add, size: 18, color: Colors.black),
                        isPlaceholder: true,
                        profileImage: userProfilePic, // ✅ show your profile image
                      );
                    }

                    final story = friendStories[index - 1];

                    // ✅ Extract friend story thumbnail or fallback to profile image
                    final storyImage = story['story_image'];
                    final profileImage = story['profile_image'];

                    final hasStory = storyImage != null && storyImage.toString().isNotEmpty;

                    final storyImageUrl = hasStory
                        ? 'https://f410765f9588.ngrok-free.app/uploads/story_image/$storyImage'
                        : '';

                    final profileImageUrl = profileImage != null && profileImage.toString().isNotEmpty
                        ? 'https://f410765f9588.ngrok-free.app/uploads/profile_image/$profileImage'
                        : null;

                    return _buildStoryCard(
                      imageUrl: storyImageUrl,
                      username: story['username'] ?? '',
                      centerWidget: const Icon(Icons.favorite, size: 18, color: Colors.white),
                      isPlaceholder: !hasStory, // ✅ show profile image if no story
                      profileImage: profileImageUrl,
                    );
                  },
                ),

              ),

              // ---------- Bottom Action Bar ----------
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 40,
                      width: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Colors.pink, Colors.purple],
                          stops: [0.0, 0.5],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.black),
                            onPressed: (){
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => CameraScreen()),
                              );
                            }
                          ),
                          IconButton(
                            icon: const Icon(Icons.photo_library, color: Colors.black),
                            onPressed: (){
                              Navigator.push(context,
                              MaterialPageRoute(builder: (_) => GalleryScreen()),
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -5,
                      left: 110,
                      child: Container(
                        height: 50,
                        width: 45,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: const EdgeInsets.all(0),
                          icon: Image.asset('assets/images/ic_add.png', height: 26, width: 26),
                          onPressed: () {
                            if (userId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostScreen(userId: userId!), // ✅ Use non-null value
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('User ID not found. Please log in again.')),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              ...postFeed.map((post) => PostCard(postData: post)).toList(),

              // ---------- REELS ----------
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text("Reels", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: reels.length,
                  itemBuilder: (context, index) {
                    final reel = reels[index];

                   final baseUrl = 'https://f410765f9588.ngrok-free.app'; // Replace with actual IP and port
                    final thumbnailPath = reel.url ?? '';
                    final thumbnailUrl = thumbnailPath.startsWith('http')
                        ? thumbnailPath
                        : '$baseUrl$thumbnailPath';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                            MaterialPageRoute(
                              builder: (_) => ReelScreen(
                                initialIndex: index,
                                reels: posts,
                              ),
                        ),
                        );
                      },
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            width: 100,
                            height: 160,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: CachedNetworkImageProvider(thumbnailUrl),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),


              // ---------- SUGGESTIONS ----------
              if (suggestions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Suggested for you",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SuggestionFullviewScreen(suggestions: suggestions),
                            ),
                          );
                        },
                        child: const Text(
                          "More",
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      return SuggestionCard(
                        key: ValueKey(suggestion['userId']),
                        suggestion: suggestion,
                        fullSuggestionList: suggestions, // ← Pass the whole suggestions list
                        startIndex: index, // ← Optional: pass index if needed for full view
                        onRemove: () {
                          setState(() {
                            suggestions.removeAt(index);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
// ---------------------- Custom Clipper -------------------------
class ConcaveTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double bottomRadius = 20.0;
    const double dipRadius = 20.0;

    Path path = Path();

    path.moveTo(0, 0);
    path.lineTo(size.width / 2 - dipRadius, 0);
    path.arcToPoint(
      Offset(size.width / 2 + dipRadius, 0),
      radius: const Radius.circular(dipRadius),
      clockwise: false,
    );
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - bottomRadius);
    path.quadraticBezierTo(
        size.width, size.height, size.width - bottomRadius, size.height);
    path.lineTo(bottomRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - bottomRadius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class PostCard extends StatefulWidget {
  final MediaItem postData;

  const PostCard({required this.postData, super.key});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  List<String> comments = [];
  final TextEditingController _commentController = TextEditingController();

  String postUserId = '';
  String? profilePic; // Nullable, since default image is used if null
  String userName = '';
  String musicTitle = '';
  String location = '';
  String postImage = '';

  bool isLiked = false;
  int likeCount = 0;
  int commentCount = 0;
  int shareCount = 0;
  List<String> likedByProfiles = [];

  String postId = '';
  String userId = '';

  bool isLoadingUploaderInfo = true;
  bool _showHeart = false;
  double? postLatitude;
  double? postLongitude;




  @override
  void initState() {
    super.initState();
    _initializePostData();
  }

  Future<void> _initializePostData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      final post = widget.postData;

      postId = post.id;
      userId = prefs.getString('userId') ?? '';
      postUserId = post.uploaderId;
      musicTitle = "";
      location = post.location ?? '';
      postImage = post.url;
      isLiked = post.likedByProfiles.contains(userId);
      likeCount = post.likeCount;
      commentCount = post.commentCount;
      shareCount = 0;
      likedByProfiles = post.likedByProfiles;

      // ✅ Initialize latitude and longitude
      postLatitude = double.tryParse(post.latitude?.toString() ?? '');
      postLongitude = double.tryParse(post.longitude?.toString() ?? '');

    });

    await fetchUploaderInfo(widget.postData.uploaderId);

    setState(() {
      isLoadingUploaderInfo = false;
    });
  }


  Future<void> fetchUploaderInfo(String uploaderId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print("No token found.");
      return;
    }

    final url = 'https://f410765f9588.ngrok-free.app/api/user/profile/$uploaderId';
    final res = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    print("Fetching uploader info for: $uploaderId");
    print("Status Code: ${res.statusCode}");
    print("Response Body: ${res.body}");

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final baseUrl = 'https://f410765f9588.ngrok-free.app';

      setState(() {
        userName = data['name'] ?? '';
        profilePic = data['profile_image'] != null && data['profile_image'].toString().isNotEmpty
            ? '$baseUrl/uploads/profile_image/${data['profile_image']}'
            : null; // You can fall back to an icon in the widget if null
      });
    } else {
      print("Failed to fetch uploader info: ${res.statusCode}");
    }
  }





  void _handleDoubleTapLike() async {
    if (!isLiked) {
      setState(() {
        isLiked = true;
        likeCount += 1;
        _showHeart = true;
      });

      Future.delayed(Duration(milliseconds: 700), () {
        setState(() {
          _showHeart = false;
        });
      });

      try {
        final response = await http.post(
          Uri.parse('https://f410765f9588.ngrok-free.app/post/$postId/like'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId}),
        );

        if (response.statusCode != 200) {
          // Rollback UI if backend call fails
          setState(() {
            isLiked = false;
            likeCount -= 1;
          });
          print('Failed to like post: ${response.body}');
        }
      } catch (e) {
        // Rollback UI in case of network error
        setState(() {
          isLiked = false;
          likeCount -= 1;
        });
        print('Error liking post: $e');
      }
    }
  }

  Future<void> fetchComments() async {
    try {
      final res = await http.get(Uri.parse('https://f410765f9588.ngrok-free.app/post/$postId/comments'));
      if (res.statusCode == 200) {
        final List<dynamic> fetched = jsonDecode(res.body);
        setState(() {
          comments = fetched.map((e) => e['comment'].toString()).toList();
        });
      }
    } catch (e) {
      print('Error fetching comments: $e');
    }
  }

  Future<void> sendComment(String text) async {
    try {
      final res = await http.post(
        Uri.parse('https://f410765f9588.ngrok-free.app/post/$postId/comment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'comment': text}),
      );

      if (res.statusCode != 200) {
        print('Failed to comment');
      }
    } catch (e) {
      print('Error sending comment: $e');
    }
  }


  void _openCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder(
          future: fetchComments(), // fetch comments from backend
          builder: (context, snapshot) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: 400,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: comments.isEmpty
                          ? Center(child: Text('No comments yet'))
                          : ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) => ListTile(
                          leading: Icon(Icons.person),
                          title: Text(comments[index]),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () async {
                            final text = _commentController.text.trim();
                            if (text.isNotEmpty) {
                              await sendComment(text);
                              setState(() {
                                comments.add(text);
                                commentCount++;
                              });
                              _commentController.clear();
                            }
                          },
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingUploaderInfo) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: GestureDetector(
            onDoubleTap: _handleDoubleTapLike,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  height: 515,
                  width: 390,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(postImage),
                      fit: BoxFit.cover,
                    ),
                    color: Colors.grey,
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10, top: 10),
                        child: Container(
                          height: 60,
                          width: 250,
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(153),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5, left: 10),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OtherUserProfileScreen(otherUserId: postUserId),
                                      ),
                                    );
                                  },
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: (profilePic != null && profilePic!.isNotEmpty)
                                        ? NetworkImage(profilePic!)
                                        : null,
                                    child: (profilePic == null || profilePic!.isEmpty)
                                        ? const Icon(Icons.person, size: 24)
                                        : null,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  OtherUserProfileScreen(otherUserId: postUserId);
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),
                                    GestureDetector(
                                      onTap: () {
                                        if (widget.postData.taggedPeople.isNotEmpty) {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              final taggedPeople = widget.postData.taggedPeople;

                                              return AlertDialog(
                                                title: const Text("Tagged People"),
                                                content: SizedBox(
                                                  width: double.maxFinite,
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: taggedPeople.length,
                                                    itemBuilder: (context, index) {
                                                      return ListTile(
                                                        title: Text(taggedPeople[index]),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    child: const Text("Close"),
                                                    onPressed: () => Navigator.pop(context),
                                                  )
                                                ],
                                              );
                                            },
                                          );
                                        }
                                      },
                                     child: Text(
                                       widget.postData.taggedPeople.isNotEmpty
                                           ? '$userName and others'
                                           : userName,
                                       style: const TextStyle(
                                         color: Colors.white,
                                         fontSize: 16,
                                         fontWeight: FontWeight.bold,
                                         decoration: TextDecoration.underline,
                                       ),
                                     ),

                                    ),
                                    const SizedBox(height: 5),
                                    if (musicTitle != null && musicTitle.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.music_note, size: 16, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            musicTitle,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 0, right: 8),
                          child: Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white, size: 40),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    backgroundColor: Colors.white,
                                    builder: (BuildContext context) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.share),
                                              title: const Text('Share'),
                                              onTap: () => Navigator.pop(context),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.bookmark),
                                              title: const Text('Save'),
                                              onTap: () => Navigator.pop(context),
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.report),
                                              title: const Text('Report'),
                                              onTap: () => Navigator.pop(context),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: IconButton(
                                  icon: const Icon(Icons.explore, color: Colors.white, size: 30),
                                  onPressed: () {
                                    final lat = postLatitude;
                                    final lng = postLongitude;

                                    if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MapScreen(
                                            latitude: lat,
                                            longitude: lng,
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No valid coordinates available')),
                                      );
                                    }
                                  },
                                ),
                              ),

                            ],
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
                // ❤️ Animated heart
                AnimatedOpacity(
                  opacity: _showHeart ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 100,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action Buttons Row
        Align(
          alignment: Alignment.bottomLeft,
          child: Row(
            children: [
              IconButton(
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 30, color: isLiked ? Colors.red : null),
                onPressed: _handleDoubleTapLike,
              ),
              Text(
                '$likeCount',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined, size: 28),
                onPressed: () => _openCommentSheet(context),
              ),
              Text(
                '$commentCount',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 26),
                onPressed: () {
                  // Share logic
                },
              ),
              const Spacer(),
              const Icon(
                Icons.bookmark_border,
                size: 28,
              ),
            ],
          ),
        ),

        // Likes info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: Colors.black),
              children: [
                const TextSpan(text: 'Liked by '),
                if (likedByProfiles.isNotEmpty)
                  TextSpan(
                    text: '${likedByProfiles.first} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const TextSpan(text: 'and '),
                TextSpan(
                  text: '${likedByProfiles.length - 1} others',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),

        // Caption
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 14),
              children: [
                TextSpan(text: widget.postData.caption),
              ],
            ),
          ),
        ),

        const SizedBox(height: 50),
      ],
    );
  }
}


class SuggestionCard extends StatefulWidget {
  final Map<String, dynamic> suggestion;
  final VoidCallback? onRemove;
  final List<Map<String, dynamic>> fullSuggestionList;
  final int startIndex;

  const SuggestionCard({
    Key? key,
    required this.suggestion,
    required this.fullSuggestionList,
    required this.startIndex,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<SuggestionCard> {
  late bool isFollowing;
  late int followerCount;


  @override
  void initState() {
    super.initState();
    isFollowing = false;
    followerCount = widget.suggestion['followerCount'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = widget.suggestion;

    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtherUserProfileScreen(
                          otherUserId: suggestion['userId'],
                        ),
                      ),
                    );
                  },
                  child: Text(
                    suggestion['userName'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onRemove, // <-- Trigger the removal
                child: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 2),

          Text(
            suggestion['contentType'] ?? 'Lifestyle • Fashion',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          // Profile Image
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SuggestionFullviewScreen(
                    suggestions: widget.fullSuggestionList,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  suggestion['profilePic'] ?? '',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          if (suggestion['isMutualFollow'] == true) ...[
            const SizedBox(height: 5),
            Text(
              "By ${suggestion['followedBy']}",
              style: const TextStyle(fontSize: 9, color: Colors.black54),
            ),
          ],

          const SizedBox(height: 10),

          // Follow Button
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  isFollowing = !isFollowing;
                  followerCount += isFollowing ? 1 : -1;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isFollowing ? Colors.white : Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    fontSize: 11,
                    color: isFollowing ? Colors.blue : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
