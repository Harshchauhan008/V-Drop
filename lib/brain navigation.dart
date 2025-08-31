
import 'package:flutter/material.dart';

import 'brain_addcamp.dart';
import 'brain_homescreen.dart';
import 'brain_profile.dart';

class BrainMainNavigation extends StatefulWidget {
  final int initialIndex;

  const BrainMainNavigation({super.key, this.initialIndex = 0});

  @override
  State<BrainMainNavigation> createState() => _BrainMainNavigationState();
}

class _BrainMainNavigationState extends State<BrainMainNavigation> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 2); // to prevent crash
  }

  List<Widget> get _screens => [
    BrainHomeScreen(),
    AddCampaign(), // Assuming 3rd screen
    CreatorDashboard(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: "Add"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
