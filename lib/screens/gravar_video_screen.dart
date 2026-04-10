import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../database/database_helper.dart';
import '../models/pet.dart';
import '../models/videopet.dart';
import '../services/api_service.dart';

class GravarVideoScreen extends StatefulWidget {
  final Pet pet;
  const GravarVideoScreen({super.key, required this.pet});

  @override
  _GravarVideoScreenState createState() => _GravarVideoScreenState();
}

class _GravarVideoScreenState extends State<GravarVideoScreen> {
  CameraController? _cameraController;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(backCamera, ResolutionPreset.high);
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _toggleGravar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (_isRecording) {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      setState(() => _isRecording = false);

      final dir = await getApplicationDocumentsDirectory();
      final savedPath = path.join(dir.path, 'video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await File(videoFile.path).copy(savedPath);

      final novoVideo = VideoPet(
        petId: widget.pet.id,
        petUuid: widget.pet.uuid,
        caminhoLocal: savedPath,
        dataCadastro: DateTime.now(),
        dataUltimaAtualizacao: DateTime.now(),
        sincronizado: false,
      );

      await DatabaseHelper.instance.insertVideo(novoVideo);
      ApiService().sincronizarGeral();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vídeo salvo!')));
        Navigator.pop(context);
      }
    } else {
      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text('Gravar ${widget.pet.nome}')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          CameraPreview(_cameraController!),
          Positioned(
            bottom: 40,
            child: FloatingActionButton(
              backgroundColor: _isRecording ? Colors.red : Colors.white,
              onPressed: _toggleGravar,
              child: Icon(_isRecording ? Icons.stop : Icons.videocam, color: _isRecording ? Colors.white : Colors.red, size: 30),
            ),
          ),
          if (_isRecording)
            const Positioned(
              top: 20,
              child: Text('GRAVANDO...', style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }
}