import 'dart:convert';
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotvibe/main.dart';
import 'package:http_parser/http_parser.dart';



class AddInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const AddInfoScreen({super.key, this.userProfile});
  @override
  State<AddInfoScreen> createState() => _AddInfoScreenState();
}

class _AddInfoScreenState extends State<AddInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  Uint8List? _imageData;

  String? profilePicUrl;
  String? userId;
  DateTime? dob;
  String? gender;
  String? country;
  List<Map<String, String>> links = [];

  final _bioController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();

  final List<String> countries = ['India', 'USA', 'UK', 'Australia'];
  final List<String> genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();

    // Prefill form fields from userProfile if passed
    if (widget.userProfile != null) {
      final profile = widget.userProfile!;
      _nameController.text = profile['name'] ?? '';
      _usernameController.text = profile['username'] ?? '';
      _bioController.text = profile['bio'] ?? '';

      if (profile['dob'] != null) {
        try {
          dob = DateTime.parse(profile['dob']);
        } catch (_) {}
      }
      gender = genders.contains(profile['gender']) ? profile['gender'] : null;
      country = countries.contains(profile['country']) ? profile['country'] : null;


      if (profile['links'] != null && profile['links'] is List) {
        links = List<Map<String, String>>.from(profile['links']);
      }

      if (profile['profilePic'] != null && profile['profilePic'].toString().isNotEmpty) {
        final imageUrl = profile['profilePic'].toString();

        // Optional: You could preload image bytes, or just store the URL
        setState(() {
          profilePicUrl = imageUrl; // define this variable in your state
        });
      }
    }

    _loadUserId();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final storedUserId = prefs.getString('userId');

    if (token == null) return;

    if (storedUserId != null) {
      setState(() => userId = storedUserId);
    } else {
      try {
        final decodedToken = JwtDecoder.decode(token);
        final extractedId = decodedToken['id']?.toString();
        if (extractedId != null) {
          await prefs.setString('userId', extractedId);
          setState(() => userId = extractedId);
        }
      } catch (e) {
        print("❌ Failed to decode token: $e");
      }
    }
  }

  Future<void> saveAndContinue({bool isSkipping = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final uid = userId ?? prefs.getString('userId');

    if (token == null) {
      debugPrint("⛔ Missing token");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing token')),
      );
      return;
    }

    if (uid == null || uid.isEmpty) {
      debugPrint("⚠️ Warning: No userId found. Proceeding without it.");
    }

    if (!isSkipping && !_formKey.currentState!.validate()) {
      debugPrint("⛔ Form validation failed");
      return;
    }

    final uri = Uri.parse('https://f410765f9588.ngrok-free.app/api/user/profile/create');

    try {
      http.Response response;

      // If image is present, send as multipart
      if (_imageData != null) {
        debugPrint("📷 Uploading with profile image");

        final request = http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['name'] = _nameController.text.trim()
          ..fields['username'] = _usernameController.text.trim()
          ..fields['bio'] = _bioController.text.trim()
          ..fields['dob'] = dob?.toIso8601String() ?? DateTime.now().toIso8601String()
          ..fields['gender'] = gender ?? "Other"
          ..fields['country'] = country ?? "Unknown"
          ..fields['user_id'] = uid ?? '';


        request.files.add(http.MultipartFile.fromBytes(
          'profile_pic',
          _imageData!,
          filename: 'profile.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));

        final streamed = await request.send();
        response = await http.Response.fromStream(streamed);
      } else {
        debugPrint("📤 Sending profile without image");

        final profileData = {
          if (uid != null && uid.isNotEmpty) "user_id": uid,
          "name": _nameController.text.trim(),
          "username": _usernameController.text.trim(),
          "bio": _bioController.text.trim(),
          "dob": dob?.toIso8601String() ?? DateTime.now().toIso8601String(),
          "gender": gender ?? "Other",
          "country": country ?? "Unknown",
         // "links": links,
        };

        response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(profileData),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("✅ Profile saved successfully");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile saved successfully")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } else {
        final error = jsonDecode(response.body);
        debugPrint("❌ Server error: ${error['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${error['message']}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server error, try again.")),
      );
    }
  }


  Future<void> _pickAndCropImage() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,
      Permission.storage, // For Android < 13
    ].request();

    final isGranted = statuses.values.any((status) => status.isGranted);

    if (!isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo permission denied")),
      );
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CropImageScreen(
            imageData: bytes,
            onCropped: (cropped) => setState(() => _imageData = cropped),
          ),
        ),
      );
    }
  }

  void _addLink() {
    showDialog(
      context: context,
      builder: (context) {
        String type = '', url = '';
        return AlertDialog(
          title: const Text('Add Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Type'),
                onChanged: (v) => type = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'URL'),
                onChanged: (v) => url = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (type.isNotEmpty && url.isNotEmpty) {
                  setState(() => links.add({"type": type, "url": url}));
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage:
                _imageData != null ? MemoryImage(_imageData!) : null,
                child: _imageData == null ? const Icon(Icons.person, size: 50) : null,
              ),
              TextButton(
                onPressed: _pickAndCropImage,
                child: const Text('Change Photo'),
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v!.isEmpty ? 'Enter username' : null,
              ),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              ListTile(
                title: Text(dob == null
                    ? 'Select DOB'
                    : DateFormat('yMMMd').format(dob!)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dob ?? DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => dob = picked);
                },
              ),
              DropdownButtonFormField<String>(
                value: genders.contains(gender) ? gender : null,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: genders
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => gender = v),
              ),
              DropdownButtonFormField<String>(
                value: countries.contains(country) ? country : null,
                decoration: const InputDecoration(labelText: 'Country'),
                items: countries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => country = v),
              ),
              const SizedBox(height: 10),
              ...links.map(
                    (link) => ListTile(
                  title: Text(link['type']!),
                  subtitle: Text(link['url']!),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => setState(() => links.remove(link)),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addLink,
                icon: const Icon(Icons.add),
                label: const Text('Add Link'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () => saveAndContinue(isSkipping: true),
                    child: const Text('Skip for Now'),
                  ),
                  ElevatedButton(
                    onPressed: () => saveAndContinue(),
                    child: const Text('Save & Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CropImageScreen extends StatelessWidget {
  final Uint8List imageData;
  final void Function(Uint8List croppedData) onCropped;
  final CropController _controller = CropController();

  CropImageScreen({required this.imageData, required this.onCropped, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Image')),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: imageData,
              controller: _controller,
              onCropped: (cropped) {
                onCropped(cropped);
                Navigator.pop(context);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.crop),
              label: const Text("Crop"),
              onPressed: () => _controller.crop(),
            ),
          )
        ],
      ),
    );
  }
}
