import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:spotvibe/Brain_setting%20&%20Activity.dart';

class CreatorDashboard extends StatefulWidget {
  const CreatorDashboard({super.key});
  @override
  _CreatorDashboardState createState() => _CreatorDashboardState();
}

class _CreatorDashboardState extends State<CreatorDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> profileData;
  List<Map<String, dynamic>> tabData = [{}, {}, {}]; // Photos, Grid, Reels
  List<bool> isLoading = [true, true, true];


  @override
  void initState() {
    super.initState();
    profileData = fetchProfileData();

    _tabController = TabController(length: 3, vsync: this);

    // Fetch server stats for each tab
    for (int i = 0; i < 3; i++) {
      fetchData(i);
    }
  }

  Future<Map<String, dynamic>> fetchProfileData() async {
    await Future.delayed(Duration(seconds: 1)); // Simulated delay
    return {
      'profileImage': 'assets/images/HarshDp.jpeg',
      'name': 'Harsh chauhan',
      'topContent': [
        {'imagePath': 'assets/images/Content01.png', 'label': 'Reel 1'},
        {'imagePath': 'assets/images/Content02.png', 'label': 'Reel 2'},
        {'imagePath': 'assets/images/Content03.png', 'label': 'Reel 3'},
      ],
      'brands': [
        {'logoPath': 'assets/images/nike.png', 'name': 'Nike'},
        {'logoPath': 'assets/images/apple.png', 'name': 'Apple'},
      ],
    };
  }

  Future<void> fetchData(int tabIndex) async {
    setState(() => isLoading[tabIndex] = true);
    try {
      final response = await http.get(Uri.parse('http://192.168.0.184:5000/api/stats?tab=$tabIndex'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          tabData[tabIndex] = data;
          isLoading[tabIndex] = false;
        });
      } else {
        print("Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("Fetch error (tab $tabIndex): $e");
    }
  }

  Widget statCard(String title, String value, IconData icon) {
    return Container(
      width: 150,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 18)),
          Text(title, style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget buildTabContent(int index) {
    // if (isLoading[index]) {
    //   return Center(child: CircularProgressIndicator());
    // }
    // final data = tabData[index];
    final Map<String, dynamic> data = {
      "views": "6.5M",
      "engagement": "12.5%",
      "viral": "1.4M",
      "likes": "38k",
    };

    return Center(
      child: Wrap(
        spacing: 10,
        runSpacing: 20,
        children: [
          statCard("Total Views", data["views"] ?? "-", Icons.visibility),
          statCard("Engagement", data["engagement"] ?? "-", Icons.bar_chart),
          statCard("Viral Reel", data["viral"] ?? "-", Icons.auto_awesome),
          statCard("Most Likes", data["likes"] ?? "-", Icons.favorite),
        ],
      ),
    );
  }

  Widget brandTile(Map brand) {
    return ListTile(
      leading: CircleAvatar(backgroundImage: AssetImage(brand['logoPath'])),
      title: Text(brand['name'], style: TextStyle(color: Colors.white)),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BrainSettingsAndActivityScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: profileData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text("Error loading profile", style: TextStyle(color: Colors.white)));
          }

          final data = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 40),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage(data['profileImage']),
                ),
                SizedBox(height: 15),
                Text(data['name'], style: TextStyle(fontSize: 20, color: Colors.white)),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Chip(label: Text('Entrepreneur')),
                    SizedBox(width: 8),
                    Chip(label: Text('YouTuber')),
                  ],
                ),
                SizedBox(height: 30),
                ElevatedButton(onPressed: () {}, child: Text("Message")),
                SizedBox(height: 40),

                // TabBar for social platform stats
                DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        tabs: [
                          Tab(icon: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset('assets/images/SpotVibe_Logo.png', height: 30))),
                          Tab(icon: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset('assets/images/instagram.png', height: 30))),
                          Tab(icon: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset('assets/images/youtube.png', height: 30))),
                        ],
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        height: 260, // Fixed height for TabBarView
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            buildTabContent(0),
                            buildTabContent(1),
                            buildTabContent(2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),
                Text("Top Content", style: TextStyle(color: Colors.white, fontSize: 18)),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(data['topContent'].length, (index) {
                    final content = data['topContent'][index];
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            content['imagePath'],
                            width: 100,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(height: 5),
                      //  Text(content['label'], style: TextStyle(color: Colors.white70, fontSize: 12))
                      ],
                    );
                  }),
                ),

                SizedBox(height: 20),
                Text("Works with Brands", style: TextStyle(color: Colors.white, fontSize: 18)),
                ...data['brands'].map<Widget>((brand) => brandTile(brand)).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
