import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> onlineUsers = [];
  List<dynamic> chatUsers = [];
  List<dynamic> searchResults = [];
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchOnlineUsers();
    fetchChatUsers();
  }

  Future<void> fetchOnlineUsers() async {
    final res = await http.get(Uri.parse('https://f410765f9588.ngrok-free.app/api/online-users'));
    if (res.statusCode == 200) {
      setState(() {
        onlineUsers = json.decode(res.body);
      });
    }
  }

  Future<void> fetchChatUsers() async {
    final res = await http.get(Uri.parse('https://f410765f9588.ngrok-free.app/api/chat-users'));
    if (res.statusCode == 200) {
      setState(() {
        chatUsers = json.decode(res.body);
      });
    }
  }

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        isSearching = false;
        searchResults.clear();
      });
      return;
    }

    final res = await http.get(Uri.parse('https://f410765f9588.ngrok-free.app/api/search-users?query=$query'));
    if (res.statusCode == 200) {
      setState(() {
        isSearching = true;
        searchResults = json.decode(res.body);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = isSearching ? searchResults : chatUsers;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        title: Text('Messages'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              onChanged: searchUsers,
              decoration: InputDecoration(
                hintText: 'Search user...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),

          // Online Users
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: onlineUsers.length,
              itemBuilder: (context, index) {
                final user = onlineUsers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundImage: NetworkImage(user['profilePic']),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 6,
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(user['username'], style: TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),

          // Chat User List
          Expanded(
            child: ListView.builder(
              itemCount: displayList.length,
              itemBuilder: (context, index) {
                final user = displayList[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user['profilePic']),
                  ),
                  title: Text(user['username']),
                  subtitle: Text(user['lastMessage'] ?? 'No message'),
                  trailing: Icon(Icons.camera_alt_outlined),
                  onTap: () {
                    // Navigate to chat detail screen with user['userId']
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
