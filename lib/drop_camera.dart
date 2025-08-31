import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';

import 'drop_screen.dart';

class DropCamera extends StatefulWidget {
  @override
  _DropCameraState createState() => _DropCameraState();
}

class _DropCameraState extends State<DropCamera> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool isRearCamera = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _startCamera(_cameras!.first);
  }

  void _startCamera(CameraDescription description) async {
    _cameraController = CameraController(description, ResolutionPreset.high);
    await _cameraController?.initialize();
    if (mounted) setState(() {});
  }

  void _toggleCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    isRearCamera = !isRearCamera;
    _startCamera(isRearCamera ? _cameras!.first : _cameras!.last);
  }

  Future<void> _takePicture() async {
    if (!_cameraController!.value.isInitialized) return;
    final XFile file = await _cameraController!.takePicture();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(imageFile: file),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(_cameraController!)),
          Positioned(
            top: 40,
            left: 15,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.switch_camera, color: Colors.white),
              onPressed: _toggleCamera,
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                iconSize: 70,
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: _takePicture,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  final XFile imageFile;

  const ImagePreviewScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    final File file = File(imageFile.path);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Image.file(file, fit: BoxFit.contain),
          ),
          Positioned(
            top: 40,
            left: 15,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 30,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context), // Retake
              icon: const Icon(Icons.camera_alt),
              label: const Text("Retake"),
            ),
          ),
          Positioned(
            bottom: 40,
            right: 30,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DropScreen(capturedImage: file),
                  ),
                );
              },
              icon: const Icon(Icons.upload),
              label: const Text("Next"),
            ),
          ),
        ],
      ),
    );
  }
}