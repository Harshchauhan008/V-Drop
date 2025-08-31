import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'other_users.dart';

class SuggestionFullviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> suggestions;
  final int startIndex;


  const SuggestionFullviewScreen({
    super.key,
    required this.suggestions,
    this.startIndex = 0,
  });

  @override
  State<SuggestionFullviewScreen> createState() => _SuggestionFullviewScreenState();
}

class _SuggestionFullviewScreenState extends State<SuggestionFullviewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final Set<String> _followedUserIds = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  // Inside _SuggestionFullviewScreenState class

  Future<void> _followUser(String userId) async {
    setState(() {
      _followedUserIds.add(userId); // Update UI instantly (optional)
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('https://2879ab6b712d.ngrok-free.app/api/follow/request/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow request sent')),
        );
      } else {
        setState(() {
          _followedUserIds.remove(userId); // Revert on failure
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to follow: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        _followedUserIds.remove(userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  Future<void> _unfollowUser(String userId) async {
    setState(() {
      _followedUserIds.remove(userId); // Optimistically update UI
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse('https://2879ab6b712d.ngrok-free.app/api/follow/unfollow/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unfollowed successfully')),
        );
      } else {
        setState(() {
          _followedUserIds.add(userId); // Revert on failure
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unfollow: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        _followedUserIds.add(userId); // Revert on error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _toggleFollow(String userId) {
    if (_followedUserIds.contains(userId)) {
      _unfollowUser(userId);
    } else {
      _followUser(userId);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.suggestions.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final suggestion = widget.suggestions[index];
          final userId = suggestion['userId']?.toString() ?? 'unknown';
          final List<String> professions = suggestion['professions'] is List
              ? List<String>.from(suggestion['professions'])
              : [];

          return Stack(
            fit: StackFit.expand,
            children: [
              // -------------------- Background Image --------------------
              Image.network(
                suggestion['imageUrl'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
              ),

              // -------------------- AppBar Icons --------------------
              Positioned(
                top: 50,
                right: 20,
                child: const Icon(Icons.more_vert, color: Colors.black),
              ),
              Positioned(
                top: 50,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // -------------------- User Info Section --------------------
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtherUserProfileScreen(
                          otherUserId: userId,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 90, left: 10, right: 100),
                    child: Container(
                      constraints: BoxConstraints(minHeight: 70),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(102),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion['name'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: professions.map((profession) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  profession,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // -------------------- Close Icon --------------------
              Positioned(
                bottom: 30,
                left: 70,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 30,),
                    onPressed: () {
                      setState(() {
                        widget.suggestions.removeAt(index);
                        if (widget.suggestions.isEmpty) Navigator.pop(context);
                      });
                    },
                  ),
                ),
              ),

              // -------------------- Follow/Unfollow Icon --------------------
              Positioned(
                bottom: 30,
                right: 70,
                child:  Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _followedUserIds.contains(userId) ? Icons.check : Icons.add,
                      color: _followedUserIds.contains(userId) ? Colors.green : Colors.purple,
                      size: 30,
                    ),
                    onPressed: () => _toggleFollow(userId),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
