import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
//import 'package:spotvibe/profile_screen.dart';
//import 'package:permission_handler/permission_handler.dart';

//import 'home_screen.dart';
import 'other_users.dart';


class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool showRadar = false;
  List<dynamic> notifications = [];
  List<dynamic> nearbyDrops = [];
  LatLng? currentLocation;
  int? currentUserId;
  bool isPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getInt('userId');
    isPrivate = prefs.getBool('isPrivate') ?? false;

    _loadNotifications();
    _getCurrentLocation();
  }

  Future<void> _loadNotifications() async {
    if (currentUserId == null) return;

    final response = await http.get(
      Uri.parse('https://f410765f9588.ngrok-free.app/api/notifications/$currentUserId'),
    );

    if (response.statusCode == 200) {
      setState(() {
        notifications = json.decode(response.body)['notifications'];
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });

    await _loadNearbyDrops(position.latitude, position.longitude);
  }

  Future<void> _loadNearbyDrops(double lat, double lng) async {
    final response = await http.post(
      Uri.parse('https://f410765f9588.ngrok-free.app/api/nearby-drops'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'latitude': lat, 'longitude': lng}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        nearbyDrops = data['drops'];
      });
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notificationData) {
    final String type = notificationData['type'];
    final String? postId = notificationData['post_id']?.toString();
    final String? fromUserId = notificationData['from_user_id']?.toString();

    switch (type) {
      case 'request_accepted':
        if (fromUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtherUserProfileScreen(otherUserId: fromUserId),
            ),
          );
        }
        break;
    // Add more cases as needed

      default:
        break;
    }
  }

  Future<void> _acceptFollowRequest(int fromUserId) async {
    final response = await http.post(
      Uri.parse('https://f410765f9588.ngrok-free.app/api/accept-follow-request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from_user_id': fromUserId,
        'to_user_id': currentUserId,
      }),
    );

    if (response.statusCode == 200) {
      _loadNotifications(); // refresh after accepting
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept follow request')),
      );
    }
  }

  Widget _buildNotificationList() {
    if (notifications.isEmpty) {
      return const Center(child: Text("No notifications yet."));
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notif = notifications[index];
        final type = notif['type'];
        final message = notif['message'] ?? '';
        final timestamp = notif['timestamp'] ?? '';
        final fromUserId = notif['from_user_id'];

        return ListTile(
          leading: Icon(_getIcon(type)),
          title: Text(message),
          subtitle: Text(timestamp),
          trailing: (type == 'follow_request' && isPrivate)
              ? ElevatedButton(
            onPressed: () => _acceptFollowRequest(fromUserId),
            child: const Text("Accept"),
          )
              : null,
          onTap: () {
            if (type != 'follow_request') {
              _handleNotificationTap(notif);
            }
          },
        );
      },
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'follow_request':
        return Icons.person_add;
      case 'request_accepted':
        return Icons.verified_user;
      case 'like':
        return Icons.thumb_up;
      case 'comment':
        return Icons.comment;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildRadarView() {
    return  RadarScreen();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          showRadar ? 'Radar' : 'Notifications',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                showRadar = !showRadar;
              });
            },
            child: Text(
              showRadar ? 'Notifications' : 'Radar',
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ),
        ],
      ),
      body: showRadar ? _buildRadarView() : _buildNotificationList(),
    );
  }
}

class RadarScreen extends StatefulWidget {
  @override
  _RadarScreenState createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  Position? _currentLocation;
  List<Map<String, dynamic>> _nearbyPosts = [];

  final String baseUrl = 'https://f410765f9588.ngrok-free.app';

  @override
  void initState() {
    super.initState();
    _fetchLocationAndDrops();
  }

  Future<void> _fetchLocationAndDrops() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition();
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null || authToken.isEmpty) return;

      final uri = Uri.parse(
          '$baseUrl/api/nearby-posts?lat=${position.latitude}&lon=${position.longitude}');

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $authToken',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> posts = decoded['data'] ?? [];

        setState(() {
          _currentLocation = position;
          _nearbyPosts = posts.cast<Map<String, dynamic>>();
        });
      } else {
        print('Failed to fetch nearby posts. Code: ${response.statusCode}');
      }
    } catch (e) {
      print("Radar error: $e");
    }
  }


  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * pi / 180;

  List<Widget> _buildDropWidgets(Size radarSize) {
    if (_currentLocation == null) return [];

    final centerX = radarSize.width / 2;
    final centerY = radarSize.height / 2;
    final List<Widget> widgets = [];

    const radarRange = 500.0;

    for (int i = 0; i < _nearbyPosts.length; i++) {
      final item = _nearbyPosts[i];
      final itemLat = item['latitude'];
      final itemLon = item['longitude'];

      if (itemLat == null || itemLon == null) continue;

      final distance = _calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        itemLat,
        itemLon,
      );

      if (distance > radarRange) continue;

      // 👇 Add this block right after distance calculation
      double effectiveDistance = distance;
      if (distance < 10) {
        effectiveDistance = 10 + (i * 30); // push overlapping pins outward
      }

      final angle = (2 * pi / _nearbyPosts.length) * i;
      final visualRadius = (effectiveDistance / radarRange) * (radarSize.width / 2 - 30);

      final dx = centerX + visualRadius * cos(angle);
      final dy = centerY + visualRadius * sin(angle);

      widgets.add(Positioned(
        left: dx,
        top: dy,
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => PostCardDialog(
                post: item,
                baseUrl: baseUrl,
              ),
            );
          },
          child: const Icon(Icons.location_pin, size: 30, color: Colors.red),
        ),
      ));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    const radarSize = Size(500, 500);

    return Center(
      child: _currentLocation == null
          ? const CircularProgressIndicator()
          : InteractiveViewer( // 👈 Add this wrapper
        maxScale: 5.0,
        minScale: 1.0,
        panEnabled: true,
        child: SizedBox(
          width: radarSize.width,
          height: radarSize.height,
          child: Stack(
            children: [
              CustomPaint(size: radarSize, painter: RadarPainter()),
              ..._buildDropWidgets(radarSize),
            ],
          ),
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint circlePaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Offset center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 2, circlePaint);
    canvas.drawCircle(center, size.width / 2, borderPaint);
    canvas.drawLine(center, Offset(center.dx, 0), borderPaint);
    canvas.drawLine(center, Offset(center.dx, size.height), borderPaint);
    canvas.drawLine(center, Offset(0, center.dy), borderPaint);
    canvas.drawLine(center, Offset(size.width, center.dy), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PostCardDialog extends StatefulWidget {
  final Map<String, dynamic> post;
  final String baseUrl;

  const PostCardDialog({
    required this.post,
    required this.baseUrl,
    super.key,
  });

  @override
  State<PostCardDialog> createState() => _PostCardDialogState();
}

class _PostCardDialogState extends State<PostCardDialog> {
  String? userName;
  String? profilePic;
  String? mediaUrl;
  String? caption;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  void _loadPostData() {
    final post = widget.post;
    final baseUrl = widget.baseUrl; // make sure this is passed in the widget

    userName = post['username'] ?? 'Unknown';

    profilePic = post['profile_image'] != null && post['profile_image'].toString().isNotEmpty
        ? post['profile_image'].toString().startsWith('http')
        ? post['profile_image'] // already a full URL
        : '$baseUrl/uploads/profile_image/${post['profile_image']}'
        : null;

    final rawImage = post['image_url'];
    print('🔍 rawImage: $rawImage');

    if (rawImage != null && rawImage.isNotEmpty) {
      mediaUrl = rawImage.startsWith('http')
          ? rawImage
          : '${widget.baseUrl}/Uploads/$rawImage'; // Corrected path here
      print('📷 Media URL: $mediaUrl');
    }
    else {
      print('❌ No image URL found in post');
    }


    caption = post['caption'] ?? 'No caption';

    setState(() {
      isLoading = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: isLoading
          ? const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: profilePic != null
                  ? NetworkImage(profilePic!)
                  : const AssetImage('assets/default_avatar.png')
              as ImageProvider,
            ),
            title: Text(userName ?? 'Unknown'),
          ),
          if (mediaUrl != null)
            Image.network(
              mediaUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Text('❌ Failed to load image');
              },
            )
          else
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('No media available'),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              caption?.isNotEmpty == true ? caption! : "No caption",
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
