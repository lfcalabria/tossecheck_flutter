import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/videopet.dart';

class ReproduzirVideoScreen extends StatefulWidget {
  final VideoPet video;
  const ReproduzirVideoScreen({super.key, required this.video});

  @override
  State<ReproduzirVideoScreen> createState() => _ReproduzirVideoScreenState();
}

class _ReproduzirVideoScreenState extends State<ReproduzirVideoScreen> {
  VideoPlayerController? _controller;
  bool _inicializado = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final file = File(widget.video.caminhoLocal);

    if (!await file.exists()) {
      setState(() {
        _erro = 'Arquivo de vídeo não encontrado no dispositivo.';
        _inicializado = false;
      });
      return;
    }

    try {
      final c = VideoPlayerController.file(file);
      _controller = c;

      await c.initialize();
      await c.setLooping(true);

      if (!mounted) return;
      setState(() {
        _inicializado = true;
        _erro = null;
      });

      await c.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Falha ao carregar o vídeo: $e';
        _inicializado = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;

    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    // não precisa setState — o VideoPlayer já atualiza via controller
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Reprodução de Vídeo'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _erro != null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _erro!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              )
            : (_inicializado && c != null)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
                      const SizedBox(height: 12),
                      VideoProgressIndicator(
                        c,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.teal,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.value.isPlaying ? 'Reproduzindo…' : 'Pausado',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(color: Colors.teal),
      ),
      floatingActionButton: (c == null || !_inicializado)
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.teal,
              onPressed: _togglePlayPause,
              child: Icon(
                c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
    );
  }
}