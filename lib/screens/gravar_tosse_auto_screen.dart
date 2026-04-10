import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/pet.dart';
// import '../services/api_service.dart'; // ✅ opcional, se quiser sync imediato

class GravarTosseAutoScreen extends StatefulWidget {
  final Pet? pet; // Se vier preenchido, tenta salvar direto para este pet

  const GravarTosseAutoScreen({super.key, this.pet});

  @override
  State<GravarTosseAutoScreen> createState() => _GravarTosseAutoScreenState();
}

class _GravarTosseAutoScreenState extends State<GravarTosseAutoScreen> {
  CameraController? _controller;
  bool _inicializando = true;
  bool _gravando = false;

  @override
  void initState() {
    super.initState();
    _initCameraEGravar();
  }

  Future<void> _initCameraEGravar() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await _controller!.initialize();

      if (!mounted) return;
      setState(() => _inicializando = false);

      // Auto start
      await _controller!.startVideoRecording();
      if (!mounted) return;
      setState(() => _gravando = true);
    } catch (e) {
      debugPrint("Erro na câmera: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  Future<String> _moverVideoParaPastaApp(String origem) async {
    final dir = await getApplicationDocumentsDirectory();
    final videosDir = Directory(p.join(dir.path, 'videos'));
    if (!await videosDir.exists()) await videosDir.create(recursive: true);

    final destino = p.join(videosDir.path, '${DateTime.now().millisecondsSinceEpoch}.mp4');

    final origemFile = File(origem);

    // tenta mover (rename). se falhar (ex: storage diferente), copia e apaga
    try {
      await origemFile.rename(destino);
      return destino;
    } catch (_) {
      await origemFile.copy(destino);
      try { await origemFile.delete(); } catch (_) {}
      return destino;
    }
  }

  Future<int?> _resolverPetIdLocal(Pet pet) async {
    // Se já tiver id local, ok
    if (pet.id != null) return pet.id;

    // Se tiver uuid do pet, tenta encontrar no banco por uuid
    if (pet.uuid != null && pet.uuid!.isNotEmpty) {
      final petNoDb = await DatabaseHelper.instance.getPetPorUuid(pet.uuid!);
      return petNoDb?.id;
    }

    // Sem id e sem uuid: não dá para resolver.
    return null;
  }

  Future<void> _pararESalvar() async {
    if (_controller == null || !_gravando) return;

    try {
      final xFile = await _controller!.stopVideoRecording();
      if (!mounted) return;

      final novoPath = await _moverVideoParaPastaApp(xFile.path);

      // Se já temos o pet, salvamos direto no banco aqui
      if (widget.pet != null) {
        final agora = DateTime.now();

        final petIdLocal = await _resolverPetIdLocal(widget.pet!);

        final video = VideoPet(
          uuid: const Uuid().v4(),
          petId: petIdLocal,                 // ✅ pode ser null sem crash
          petUuid: widget.pet!.uuid,         // ✅ ajuda no sync direto
          caminhoLocal: novoPath,
          dataCadastro: agora,
          dataUltimaAtualizacao: agora,
          sincronizado: false,
        );

        await DatabaseHelper.instance.insertVideo(video);

        // ✅ opcional: tentar sincronizar logo após gravar
        // await ApiService().sincronizarGeral();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tosse registrada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Se não tem pet, volta para a tela de seleção passando o path
        if (mounted) Navigator.pop(context, novoPath);
      }
    } catch (e) {
      debugPrint("Erro ao parar gravação: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_inicializando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: CameraPreview(_controller!)),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  const Text(
                    "GRAVANDO...",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: _pararESalvar,
                    child: const Icon(Icons.stop, size: 30, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}