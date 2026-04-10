import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/videopet.dart';

class ReproduzirVideoScreen extends StatefulWidget {
  final VideoPet video;
  const ReproduzirVideoScreen({super.key, required this.video});

  @override
  _ReproduzirVideoScreenState createState() => _ReproduzirVideoScreenState();
}

class _ReproduzirVideoScreenState extends State<ReproduzirVideoScreen> {
  late VideoPlayerController _controller;
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.video.caminhoLocal))
      ..initialize().then((_) {
        if (mounted) {
          setState(() { _inicializado = true; });
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Reprodução de Vídeo'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _inicializado
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: Colors.teal),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          setState(() {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          });
        },
        child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
      ),
    );
  }
}