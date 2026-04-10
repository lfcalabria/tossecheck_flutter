import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/pet.dart';
import '../models/videopet.dart';
import '../services/api_service.dart';

class GravarVideoScreen extends StatefulWidget {
  final Pet pet;
  const GravarVideoScreen({super.key, required this.pet});

  @override
  State<GravarVideoScreen> createState() => _GravarVideoScreenState();
}

class _GravarVideoScreenState extends State<GravarVideoScreen> {
  CameraController? _cameraController;
  bool _isRecording = false;
  bool _inicializando = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _inicializando = false);
    } catch (e) {
      debugPrint("Erro ao inicializar câmera: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  Future<String> _moverVideoParaPastaApp(String origem) async {
    final dir = await getApplicationDocumentsDirectory();
    final videosDir = Directory(path.join(dir.path, 'videos'));
    if (!await videosDir.exists()) await videosDir.create(recursive: true);

    final destino = path.join(
      videosDir.path,
      'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final origemFile = File(origem);

    // tenta mover (rename). se falhar, copia e apaga
    try {
      await origemFile.rename(destino);
      return destino;
    } catch (_) {
      await origemFile.copy(destino);
      try {
        await origemFile.delete();
      } catch (_) {}
      return destino;
    }
  }

  Future<int?> _resolverPetIdLocal(Pet pet) async {
    if (pet.id != null) return pet.id;

    // tenta achar no banco pelo uuid
    if (pet.uuid != null && pet.uuid!.isNotEmpty) {
      final petNoDb = await DatabaseHelper.instance.getPetPorUuid(pet.uuid!);
      return petNoDb?.id;
    }

    return null;
  }

  Future<void> _toggleGravar() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (_isRecording) {
      // parar gravação
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);

      // mover para pasta permanente do app
      final savedPath = await _moverVideoParaPastaApp(videoFile.path);

      final agora = DateTime.now();
      final petIdLocal = await _resolverPetIdLocal(widget.pet);

      final novoVideo = VideoPet(
        uuid: const Uuid().v4(),     // ✅ uuid local
        petId: petIdLocal,          // ✅ pode ser null sem crash
        petUuid: widget.pet.uuid,   // ✅ ajuda no sync; pode ser null se pet ainda não sincronizou
        caminhoLocal: savedPath,
        dataCadastro: agora,
        dataUltimaAtualizacao: agora,
        sincronizado: false,
      );

      await DatabaseHelper.instance.insertVideo(novoVideo);

      // tenta sincronizar (se tiver internet)
      await ApiService().sincronizarGeral();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vídeo salvo!')),
        );
        Navigator.pop(context);
      }
    } else {
      // iniciar gravação
      await _cameraController!.startVideoRecording();
      if (!mounted) return;
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
    if (_inicializando || _cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Gravar ${widget.pet.nome}'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          CameraPreview(_cameraController!),

          Positioned(
            bottom: 40,
            child: FloatingActionButton(
              backgroundColor: _isRecording ? Colors.red : Colors.white,
              onPressed: _toggleGravar,
              child: Icon(
                _isRecording ? Icons.stop : Icons.videocam,
                color: _isRecording ? Colors.white : Colors.red,
                size: 30,
              ),
            ),
          ),

          if (_isRecording)
            const Positioned(
              top: 20,
              child: Text(
                'GRAVANDO...',
                style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            )
        ],
      ),
    );
  }
}