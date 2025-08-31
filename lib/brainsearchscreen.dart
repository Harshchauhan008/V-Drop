import 'package:flutter/material.dart';

class BrainSearchScreen extends StatefulWidget {
  const BrainSearchScreen({super.key});

  @override
  State<BrainSearchScreen> createState() => _BrainSearchScreenState();
}

class _BrainSearchScreenState extends State<BrainSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> allCampaigns = [
    {
      'name': 'Nike Fitness Challenge',
      'image': 'assets/images/nike.png',
    },
    {
      'name': 'Apple Product Launch',
      'image': 'assets/images/apple.png',
    },
    {
      'name': 'Google Gemini',
      'image': 'assets/images/Google_Logo.png',
    },
    {
      'name': 'Samsung Galaxy Quest',
      'image': 'assets/images/samsung.png',
    },
  ];

  List<Map<String, String>> filteredCampaigns = [];

  @override
  void initState() {
    super.initState();
    filteredCampaigns = allCampaigns;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredCampaigns = allCampaigns
          .where((campaign) =>
          campaign['name']!.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search campaigns...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filteredCampaigns.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white24),
        itemBuilder: (context, index) {
          final campaign = filteredCampaigns[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: AssetImage(campaign['image']!),
              backgroundColor: Colors.grey[300],
            ),
            title: Text(
              campaign['name']!,
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            onTap: () {
              // Handle campaign tap or expand
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tapped on ${campaign['name']}')),
              );
            },
          );
        },
      ),
    );
  }
}
