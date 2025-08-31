

import 'package:flutter/material.dart';

import 'brainsearchscreen.dart';

class BrainHomeScreen extends StatelessWidget {
  const BrainHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundImage: AssetImage('assets/images/HarshDp.jpeg'),
              radius: 18,
            ),
            const SizedBox(width: 10),
            const Text('Harsh chauhan', style: TextStyle(color: Colors.white),),
            const Spacer(),
             Row(
               children: [
                 IconButton(
                   icon: const Icon(Icons.search, color: Colors.white),
                   onPressed: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (_) => const BrainSearchScreen()),
                     );
                   },
                 ),
                 SizedBox(width: 20,),
                 Icon(Icons.notifications_none, color: Colors.white,),
               ],
             ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Write Something ....",
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.emoji_emotions_outlined, color: Colors.white54),
                      const SizedBox(width: 12),
                      const Icon(Icons.image_outlined, color: Colors.white54),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          // Handle post action here
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Post"),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: const [
                      CircleAvatar(
                        backgroundImage: AssetImage('assets/images/nike.png'),
                        radius: 18,
                      ),
                      SizedBox(width: 10),
                      Text("Nike (India)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Spacer(),
                      Icon(Icons.more_vert, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title & Platforms
                  const Text("Let’s run the future",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text("Platforms: Instagram • YouTube Shorts • SpotVibe",
                      style: TextStyle(color: Colors.white60, fontSize: 12)),

                  const SizedBox(height: 12),

                  // Description
                  const Text("Nike is looking for creators who move with purpose.",
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text("Inspire movement through original short-form content.",
                      style: TextStyle(color: Colors.white)),

                  const SizedBox(height: 12),

                  // Requirements
                  const Text("Requirements:",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text("Follower count: 5K-50K\nContent Style: Reels / Shorts / SpotVibe\nAudience: Primarily Gen Z, Urban Fitness Enthusiasts",
                      style: TextStyle(color: Colors.white)),

                  const SizedBox(height: 12),

                  // Image
                  Center(
                    child: Image.asset('assets/images/Running_Women.png', height: 150),
                  ),

                  const SizedBox(height: 12),

                  // Deadline & Apply
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Deadline: August 25, 2025",
                          style: TextStyle(color: Colors.white60)),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // What You Get
                  const Text("What You Get:",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    "• Exclusive Nike Creator Kit\n• Featured in our Run the Future campaign\n• Paid promotion + bonuses for high performance",
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 10,),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: 100,  // Set your desired width
                      height: 40,  // Set your desired height
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle post action
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Apply"),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Text("40k View", style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 4),
            const Text(
              "#NikeCollab #RunWithNike #SpotVibeBrain #CreatorMovement",
              style: TextStyle(color: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }
}
