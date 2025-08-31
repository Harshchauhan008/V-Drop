import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotvibe/profile_screen.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String otherUserId;

  const OtherUserProfileScreen({super.key, required this.otherUserId});

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  Map<String, dynamic>? userData;
  bool isPrivate = false;
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    fetchOtherUserProfile();
  }

  Future<void> fetchOtherUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final myUserId = prefs.getString('userId');

    final uri = Uri.parse('https://f410765f9588.ngrok-free.app/api/user/profile/${widget.otherUserId}?viewer=$myUserId');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        userData = data;
        isPrivate = data['isPrivate'] ?? false;
        isFollowing = data['follow_status'] == 'accepted';
      });
    }
  }

  Future<void> toggleFollow() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // if using token-based auth

    final url = isFollowing
        ? 'https://f410765f9588.ngrok-free.app/api/follow/unfollow/${widget.otherUserId}'
        : 'https://f410765f9588.ngrok-free.app/api/follow/request/${widget.otherUserId}';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      await fetchOtherUserProfile(); // refresh state
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${json.decode(response.body)['error']}')),
      );
    }
  }


  Widget _statColumn(String title, int value) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(title),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: Text("@${userData!['username']}")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔹 Pinned Header
            if (userData!['pinnedPostImage'] != null)
              Image.network(userData!['pinnedPostImage'], height: 200, fit: BoxFit.cover),

            const SizedBox(height: 16),

            // 🔹 Profile Pic + Name + Stats
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 16),
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(userData!['profilePic']),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userData!['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          _statColumn('Posts', userData!['post_count']),
                          const SizedBox(width: 20),
                          _statColumn('Followers', userData!['followers']),
                          const SizedBox(width: 20),
                          _statColumn('Following', userData!['following']),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 🔹 Follow/Unfollow or Message Button
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: toggleFollow,
                            child: Text(
                              isFollowing
                                  ? 'Following'
                                  : (userData?['follow_status'] == 'requested' ? 'Requested' : 'Follow'),
                            ),
                          ),

                          const SizedBox(width: 12),
                          if (isFollowing)
                            OutlinedButton(
                              onPressed: () {
                                // Navigate to messaging screen
                              },
                              child: const Text('Message'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 🔹 Bio + Links
            if (userData!['bio'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(userData!['bio']),
              ),
            if (userData!['links'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  (userData!['links'] as List).map((e) => e['url']).join(", "),
                  style: const TextStyle(color: Colors.blue),
                ),
              ),

            const SizedBox(height: 20),

            // 🔐 If private and not following
            if (isPrivate && !isFollowing)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text("This account is private.")),
              )

            // 🔓 Public or Followed Profile Content
            else
              DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    const TabBar(
                      indicatorColor: Colors.black,
                      tabs: [
                        Tab(icon: Icon(Icons.photo)),
                        Tab(icon: Icon(Icons.grid_on)),
                        Tab(icon: Icon(Icons.video_library)),
                        Tab(icon: Icon(Icons.person_pin)),
                      ],
                    ),
                    SizedBox(
                      height: 500,
                      child: TabBarView(
                        children: [
                          PostsGridOther(userId: widget.otherUserId, filter: 'image'),
                          PostsGridOther(userId: widget.otherUserId),
                          PostsGridOther(userId: widget.otherUserId, filter: 'reel'),
                          TaggedPostsGridOther(userId: widget.otherUserId),
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


class PostsGridOther extends StatefulWidget {
  final String userId; // <-- passed in from profile screen
  final String? filter;

  const PostsGridOther({super.key, required this.userId, this.filter});

  @override
  State<PostsGridOther> createState() => _PostsGridOtherState();
}

class _PostsGridOtherState extends State<PostsGridOther> {
  List<MediaItem> posts = [];

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    final uri = Uri.parse(
        'https://f410765f9588.ngrok-free.app/api/user/posts/${widget.userId}${widget.filter != null ? "?filter=${widget.filter}" : ""}'
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<MediaItem> items = List<Map<String, dynamic>>.from(data['posts'] ?? [])
          .map((item) => MediaItem.fromJson(item))
          .toList();

      setState(() {
        posts = items;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filter == 'reel') {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final item = posts[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: VideoPlayerWidget(videoUrl: item.url),
          );
        },
      );
    }

    return MasonryGridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final item = posts[index];
        final isBig = widget.filter == 'image'
            ? index == 0 || index == 4
            : index == 0 || index == 3;

        return SizedBox(
          height: isBig ? 185 : 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.isVideo
                ? VideoPlayerWidget(videoUrl: item.url)
                : Image.network(
              item.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        );
      },
    );
  }
}

class TaggedPostsGridOther extends StatefulWidget {
  final String userId; // This should be the other user's ID

  const TaggedPostsGridOther({super.key, required this.userId});

  @override
  State<TaggedPostsGridOther> createState() => _TaggedPostsGridOtherState();
}

class _TaggedPostsGridOtherState extends State<TaggedPostsGridOther> {
  List<MediaItem> posts = [];

  @override
  void initState() {
    super.initState();
    fetchTaggedPosts();
  }

  Future<void> fetchTaggedPosts() async {
    final uri = Uri.parse(
        'https://f410765f9588.ngrok-free.app/api/user/tagged-posts/${widget.userId}');

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<MediaItem> items = List<Map<String, dynamic>>.from(data['posts'] ?? [])
          .map((item) => MediaItem.fromJson(item))
          .toList();

      setState(() {
        posts = items;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(child: Text('No tagged posts'));
    }

    return MasonryGridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final item = posts[index];
        return SizedBox(
          height: 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.isVideo
                ? VideoPlayerWidget(videoUrl: item.url)
                : Image.network(
              item.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
        );
      },
    );
  }
}
