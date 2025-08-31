import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StoryCalendarScreen extends StatefulWidget {
  const StoryCalendarScreen({super.key});

  @override
  State<StoryCalendarScreen> createState() => _StoryCalendarScreenState();
}

class _StoryCalendarScreenState extends State<StoryCalendarScreen> {
  Map<String, Map<String, String>> storiesByMonth = {}; // monthYear -> {date: image}
  final ScrollController _scrollController = ScrollController();
  DateTime startMonth = DateTime(2023, 1);

  @override
  void initState() {
    super.initState();
    fetchStoryDates();
  }

  Future<void> fetchStoryDates() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    final url = Uri.parse('https://2879ab6b712d.ngrok-free.app/api/user/stories/$userId');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      Map<String, Map<String, String>> grouped = {};

      for (var story in data['stories']) {
        final dateStr = story['date'];
        final image = story['image'];
        final dateObj = DateTime.parse(dateStr);

        final monthKey = DateFormat('MMMM yyyy').format(dateObj);
        grouped.putIfAbsent(monthKey, () => {});
        if (!grouped[monthKey]!.containsKey(dateStr)) {
          grouped[monthKey]![dateStr] = image;
        }
      }

      // Sort the keys in reverse (latest month first)
      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) {
          final da = DateFormat('MMMM yyyy').parse(a);
          final db = DateFormat('MMMM yyyy').parse(b);
          return db.compareTo(da); // descending
        });

      // Reorder the map
      final sortedMap = {for (var k in sortedKeys) k: grouped[k]!};

      setState(() {
        storiesByMonth = sortedMap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthKeys = storiesByMonth.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Story Calendar"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: monthKeys.length,
        itemBuilder: (context, index) {
          final key = monthKeys[index];
          final entries = storiesByMonth[key]!;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month + Year label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(key,
                      style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, idx) {
                    final dateStr = entries.keys.elementAt(idx);
                    final img = entries[dateStr];
                    final dateObj = DateTime.parse(dateStr);

                    return GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final userId = prefs.getString('userId');
                        if (userId == null) return;

                        final response = await http.get(Uri.parse(
                          'https://2879ab6b712d.ngrok-free.app/api/user/stories/$userId?date=$dateStr',
                        ));

                        if (response.statusCode == 200) {
                          final data = json.decode(response.body);
                          List<String> images = List<String>.from(data['images'] ?? []);

                          if (images.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoryViewerScreen(imageUrls: images),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('No stories available for $dateStr')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to load stories')),
                          );
                        }
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade400),
                              image: img != null
                                  ? DecorationImage(
                                image: NetworkImage(img),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                            child: img == null
                                ? Center(
                              child: Text(
                                '${dateObj.day}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            )
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


class StoryViewerScreen extends StatelessWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    PageController controller = PageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: controller,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Center(
                child: Image.network(
                  imageUrls[index],
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 40,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}