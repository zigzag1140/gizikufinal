import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:giziku/main.dart';
import 'package:giziku/services/gemini_service.dart';
import 'package:giziku/services/database_service.dart';
import 'package:giziku/screens/home_screen.dart';

class ScanFoodScreen extends StatefulWidget {
  const ScanFoodScreen({super.key});

  @override
  State<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends State<ScanFoodScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  bool _isAnalyzing = false;
  FlashMode _currentFlashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (status.isGranted && cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.max, 
        enableAudio: false,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);

      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // --- FUNGSI: TOGGLE FLASH ---
  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode newMode;
    if (_currentFlashMode == FlashMode.off) {
      newMode = FlashMode.torch;
    } else {
      newMode = FlashMode.off;
    }

    try {
      await _controller!.setFlashMode(newMode);
      setState(() {
        _currentFlashMode = newMode;
      });
    } catch (e) {
      print("Error changing flash mode: $e");
    }
  }

  // --- FUNGSI: TAP TO FOCUS ---
  Future<void> _onTapFocus(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );

    try {
      await _controller!.setExposurePoint(offset);
      await _controller!.setFocusPoint(offset);
    } catch (e) {
    }
  }

  Future<void> _takePicture() async {
    if (!_controller!.value.isInitialized) return;
    if (_isAnalyzing) return;

    try {
      final image = await _controller!.takePicture();
      if (_currentFlashMode == FlashMode.torch) {
        _toggleFlash(); 
      }

      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      print("Error taking picture: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _capturedImage = image;
      });
    }
  }

  void _retakePicture() {
    setState(() {
      _capturedImage = null;
    });
  }

  Future<void> _confirmAndAnalyze() async {
    if (_capturedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // A. Kirim ke Gemini
      String? resultJsonString = await GeminiService().analyzeFood(
        _capturedImage!.path,
      );

      if (resultJsonString != null) {
        // B. Parse JSON
        Map<String, dynamic> resultData = jsonDecode(resultJsonString);

        // --- Logika Cek Makanan ---
        bool isFood = resultData['is_food'] == true;
        String foodName = resultData['food_name'] ?? 'Objek Tidak Dikenal';

        // Ambil kalori dengan aman (handle int/string)
        int calories = 0;
        if (resultData['calories'] is int) {
          calories = resultData['calories'];
        } else if (resultData['calories'] is String) {
          calories = int.tryParse(resultData['calories']) ?? 0;
        }

        if (isFood) {
          // --- KASUS 1: INI MAKANAN (SIMPAN) ---
          print("Makanan Terdeteksi: $foodName, $calories kkal");

          String uid = FirebaseAuth.instance.currentUser!.uid;
          await DatabaseService().logFoodItem(uid, foodName, calories);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Sukses! $foodName (+ $calories kkal)"),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        } else {
          // --- KASUS 2: BUKAN MAKANAN (TOLAK) ---
          print("Objek bukan makanan: $foodName");

          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Objek Tidak Valid"),
                content: const Text(
                  "Nutribot mendeteksi objek ini bukan makanan. Silakan foto ulang makanan Anda.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Oke"),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        throw Exception("Gagal mendapatkan respon dari AI");
      }
    } catch (e) {
      print("Error Analysis: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal menganalisis. Coba lagi.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    var scale = 1.0;

    if (_controller != null && _controller!.value.isInitialized) {
      scale = 1 / (_controller!.value.aspectRatio * size.aspectRatio);
      if (scale < 1) scale = 1 / scale;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // --- LAYER 1: TAMPILAN UTAMA ---
          if (_capturedImage != null)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
            )
          else if (_isCameraInitialized)
            GestureDetector(
              onTapDown: (details) {
                _onTapFocus(
                  details,
                  BoxConstraints(maxWidth: size.width, maxHeight: size.height),
                );
              },
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: Center(child: CameraPreview(_controller!)),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // --- LAYER 2: HEADER (CLOSE & FLASH) ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_capturedImage == null)
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 30),

                  const Text(
                    'Scan Makanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (_capturedImage == null)
                    IconButton(
                      icon: Icon(
                        _currentFlashMode == FlashMode.off
                            ? Icons.flash_off
                            : Icons.flash_on,
                        color: _currentFlashMode == FlashMode.off
                            ? Colors.white
                            : Colors.yellow,
                        size: 30,
                      ),
                      onPressed: _toggleFlash,
                    )
                  else
                    const SizedBox(width: 30),
                ],
              ),
            ),
          ),

          // --- LAYER 3: KOTAK FOKUS & TEXT PETUNJUK ---
          if (_capturedImage == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          child: _buildCorner(false, false),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: _buildCorner(false, true),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: _buildCorner(true, false),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: _buildCorner(true, true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Arahkan kamera ke makanan",
                      style: TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // --- LAYER 4: TOMBOL KONTROL BAWAH ---
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _capturedImage == null
                ? _buildCameraControls()
                : _buildConfirmationControls(),
          ),

          // --- LAYER 5: LOADING OVERLAY ---
          if (_isAnalyzing)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2ECC45)),
                    SizedBox(height: 20),
                    Text(
                      "Sedang Menganalisis...",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Mohon tunggu sebentar",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner(bool isBottom, bool isRight) {
    double length = 30;
    double thickness = 4;
    return Container(
      width: length,
      height: length,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(
          top: isBottom
              ? BorderSide.none
              : BorderSide(color: const Color(0xFF2ECC45), width: thickness),
          bottom: isBottom
              ? BorderSide(color: const Color(0xFF2ECC45), width: thickness)
              : BorderSide.none,
          left: isRight
              ? BorderSide.none
              : BorderSide(color: const Color(0xFF2ECC45), width: thickness),
          right: isRight
              ? BorderSide(color: const Color(0xFF2ECC45), width: thickness)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: (isBottom || isRight)
              ? Radius.zero
              : const Radius.circular(10),
          topRight: (isBottom || !isRight)
              ? Radius.zero
              : const Radius.circular(10),
          bottomLeft: (!isBottom || isRight)
              ? Radius.zero
              : const Radius.circular(10),
          bottomRight: (!isBottom || !isRight)
              ? Radius.zero
              : const Radius.circular(10),
        ),
      ),
    );
  }

  Widget _buildCameraControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: _pickFromGallery,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Icon(
              Icons.photo_library,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        GestureDetector(
          onTap: _takePicture,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 4),
            ),
            child: Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.black12, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 50),
      ],
    );
  }

  Widget _buildConfirmationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: _retakePicture,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: const Icon(Icons.close, color: Colors.red, size: 32),
          ),
        ),

        GestureDetector(
          onTap: _confirmAndAnalyze,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC45),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ECC45).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
        ),
      ],
    );
  }
}
