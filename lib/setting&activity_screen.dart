import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:spotvibe/Brain_setting%20&%20Activity.dart';
import 'package:spotvibe/main.dart';
import 'drop_screen.dart';
import 'login_screen.dart';

class SettingsAndActivityScreen extends StatefulWidget {
  const SettingsAndActivityScreen({super.key});

  @override
  State<SettingsAndActivityScreen> createState() => _SettingsAndActivityScreenState();
}

class _SettingsAndActivityScreenState extends State<SettingsAndActivityScreen> {
  bool isPrivate = false;
  String? profilePic;

  @override
  void initState() {
    super.initState();
    loadPrivacyStatus();
  }

  Future<void> loadPrivacyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token == null || userId == null) return;

    final response = await http.get(
      Uri.parse('https://f410765f9588.ngrok-free.app/api/user/profile/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      const baseUrl = 'https://f410765f9588.ngrok-free.app';

      setState(() {
        isPrivate = prefs.getBool('isPrivate') ?? false;
        profilePic = data['profile_image'] != null && data['profile_image'].toString().isNotEmpty
            ? '$baseUrl/uploads/profile_image/${data['profile_image']}'
            : null;
      });
    }
  }


  Future<void> updatePrivacyStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPrivate', value);
    setState(() => isPrivate = value);
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await GoogleSignIn().signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('signedup', false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MainNavigation()), // ← Your profile screen widget
          );
          return false;
        },
        child:  Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Setting & Activity"),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account info
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
               Navigator.push(context,
               MaterialPageRoute(builder: (_) => UserProfileDetailScreen())
               );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: profilePic != null
                        ? NetworkImage(profilePic!)
                        : null, // No image if null
                    child: profilePic == null
                        ? const Icon(Icons.person, size: 30, color: Colors.white)
                        : null, // Don't show icon if image is loaded
                    backgroundColor: Colors.grey.shade400, // Optional background for icon
                  ),

                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Your Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Password, Security, Personal details, Ad preferences",
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Special Tools
          const Text("Special Tools", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Heart
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite, color: Colors.red, size: 40),
                  ),
                  const SizedBox(height: 5),
                  const Text("Heart"),
                ],
              ),

              // Drop
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DropScreen()));
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.opacity, color: Colors.blue, size: 40),
                    ),
                    const SizedBox(height: 5),
                    const Text("Drop"),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => BrainSettingsAndActivityScreen())
                  );
                },
                child:   Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.memory, color: Colors.black, size: 40),
                  ),
                  const SizedBox(height: 5),
                  const Text("Brain"),
                ],
              ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "Navigate your world with "),
                TextSpan(text: "Heart", style: TextStyle(color: Colors.red)),
                TextSpan(text: " (social settings), "),
                TextSpan(text: "Drop", style: TextStyle(color: Colors.blue)),
                TextSpan(text: " (create & share), and "),
                TextSpan(text: "Brain", style: TextStyle(color: Colors.black)),
                TextSpan(text: " (connect with brands & influencers)."),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Navigate to map or other feature
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              ),
              child: const Text("Map"),
            ),
          ),

          const SizedBox(height: 24),

          // Uses section
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bookmark_border),
                  title: const Text("Saved"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text("Archive"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.timeline),
                  title: const Text("Your activity"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text("Notification"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text("Time management"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Privacy
          SwitchListTile(
            title: const Text("Private Account"),
            subtitle: const Text("Only approved users can follow you"),
            value: isPrivate,
            onChanged: updatePrivacyStatus,
          ),

          const SizedBox(height: 16),

          // Activity
          const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.favorite_border),
            title: Text("You liked a post"),
          ),
          const ListTile(
            leading: Icon(Icons.person_add_alt_1),
            title: Text("Someone followed you"),
          ),

          const SizedBox(height: 32),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () => _logout(context),
          ),
        ],
      ),
        ),
    );
  }
}

class UserProfileDetailScreen extends StatefulWidget {
  const UserProfileDetailScreen({super.key});

  @override
  State<UserProfileDetailScreen> createState() => _UserProfileDetailScreenState();
}

class _UserProfileDetailScreenState extends State<UserProfileDetailScreen> {
  Map<String, dynamic>? profileData;
  bool isCreatorTypeExpanded = false;
  final TextEditingController _aboutController = TextEditingController();
  List<String> creatorTypes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    _loadCreatorTypes();
  }

  void _loadCreatorTypes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      creatorTypes = prefs.getStringList('creatorTypes') ?? [];
    });
  }

  Future<void> fetchUserProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        print("User ID not found in SharedPreferences.");
        setState(() => isLoading = false);
        return;
      }

      final url = Uri.parse('https://f410765f9588.ngrok-free.app/api/user/profile/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          profileData = data['user'];
          creatorTypes = List<String>.from(data['user']['content_category'] ?? []);
          isLoading = false;
        });
      } else {
        print('Failed to fetch profile: ${response.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching profile: $e');
      setState(() => isLoading = false);
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String? value, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value ?? 'Not provided', style: const TextStyle(color: Colors.grey)),
      onTap: onTap,
    );
  }

  String? _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return null;
    try {
      final date = DateTime.parse(isoDate);
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (profileData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Profile')),
        body: const Center(
          child: Text("Failed to load profile. Please try again later.", style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Your Profile'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isCreatorTypeExpanded ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                isCreatorTypeExpanded = !isCreatorTypeExpanded;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: profileData!['profilePic'] != null
                        ? MemoryImage(base64Decode(profileData!['profilePic']))
                        : null,
                    child: profileData!['profilePic'] == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profileData!['name'] ?? 'No name',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '@${profileData!['username'] ?? ''}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (profileData!['bio'] ?? '').isNotEmpty ? profileData!['bio'] : '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: (profileData!['bio'] ?? '').isNotEmpty ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.cake, 'Date of Birth', _formatDate(profileData!['dob'])),
            _buildDetailRow(Icons.wc, 'Gender', profileData!['gender']),
            _buildDetailRow(Icons.flag, 'Country', profileData!['country']),

            if (creatorTypes.isNotEmpty || true) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Creator Types:", style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        isCreatorTypeExpanded = true;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (creatorTypes.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: creatorTypes.map((type) => Chip(label: Text(type))).toList(),
                ),
            ],

            if (isCreatorTypeExpanded) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _aboutController,
                decoration: const InputDecoration(
                  labelText: 'Add Creator Type (e.g., Travel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Add Creator Type'),
                onPressed: () async {
                  final newType = _aboutController.text.trim();
                  if (newType.isEmpty) return;

                  final prefs = await SharedPreferences.getInstance();
                  final userId = prefs.getString('userId');

                  final url = Uri.parse('https://f410765f9588.ngrok-free.app/api/user/update-category/$userId');
                  final res = await http.put(
                    url,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'content_category': newType}),
                  );

                  if (res.statusCode == 200) {
                    setState(() {
                      creatorTypes.add(newType);
                      _aboutController.clear();
                      isCreatorTypeExpanded = false;
                    });
                    prefs.setStringList('creatorTypes', creatorTypes);
                  } else {
                    print("Failed to update category: ${res.body}");
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
