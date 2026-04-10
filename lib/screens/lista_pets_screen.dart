import 'dart:io';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/pet.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import 'cadastro_pet_screen.dart';
import 'editar_pet_screen.dart';
import 'gravar_tosse_auto_screen.dart';
import 'selecionar_pet_video_screen.dart';

class ListaPetsScreen extends StatefulWidget {
  const ListaPetsScreen({super.key});

  @override
  State<ListaPetsScreen> createState() => _ListaPetsScreenState();
}

class _ListaPetsScreenState extends State<ListaPetsScreen> {
  Usuario? _usuario;
  List<Pet> _pets = [];
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();

    // Atualiza tela quando sync terminar
    ApiService().onSyncComplete = () {
      if (mounted) _carregarDados();
    };
  }

  @override
  void dispose() {
    // Evita callback apontando para state já destruído
    ApiService().onSyncComplete = null;
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final u = await DatabaseHelper.instance.getUsuario();
    final p = await DatabaseHelper.instance.getPets();
    if (!mounted) return;
    setState(() {
      _usuario = u;
      _pets = p;
    });
  }

  Future<void> _forcarSync() async {
    if (_sincronizando) return;
    setState(() => _sincronizando = true);
    try {
      await ApiService().sincronizarGeral();
      // _carregarDados será chamado via onSyncComplete se houver updates
      // mas chamamos aqui também para refletir rapidamente
      await _carregarDados();
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  // Fluxo 1: Gravar sem pet selecionado (Botão Vermelho)
  Future<void> _gravarSemPet() async {
    final videoPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const GravarTosseAutoScreen()),
    );

    if (videoPath != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelecionarPetVideoScreen(videoPath: videoPath),
        ),
      );
      await _carregarDados();
    }
  }

  // Fluxo 2: Gravar com pet já selecionado (Toque no Card)
  Future<void> _gravarComPet(Pet pet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GravarTosseAutoScreen(pet: pet)),
    );
    await _carregarDados();
  }

  ImageProvider? _petImage(String? fotoPath) {
    if (fotoPath == null || fotoPath.isEmpty) return null;
    final f = File(fotoPath);
    if (!f.existsSync()) return null;
    return FileImage(f);
  }

  String _subtituloPet(Pet pet) {
    final raca = pet.raca;
    if (raca == null || raca.trim().isEmpty) return 'Raça não informada';
    return raca;
  }

  @override
  Widget build(BuildContext context) {
    final nome = _usuario?.primeiroNome ?? "";

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, $nome'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CadastroPetScreen()),
              );
              await _carregarDados();
            },
          ),
          IconButton(
            icon: _sincronizando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _sincronizando ? null : _forcarSync,
          ),
        ],
      ),
      body: _pets.isEmpty
          ? const Center(child: Text('Nenhum pet cadastrado.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pets.length,
              itemBuilder: (context, index) {
                final pet = _pets[index];

                final img = _petImage(pet.fotoPath);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: img,
                      child: img == null ? const Icon(Icons.pets) : null,
                    ),
                    title: Text(pet.nome),
                    subtitle: Text(_subtituloPet(pet)),

                    // 1 clique grava tosse direto no pet
                    onTap: () => _gravarComPet(pet),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Indicador simples de sync do pet
                        Icon(
                          pet.sincronizado ? Icons.cloud_done : Icons.cloud_upload,
                          color: pet.sincronizado ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditarPetScreen(pet: pet),
                              ),
                            );
                            await _carregarDados();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        label: const Text("GRAVAR TOSSE", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.videocam, color: Colors.white),
        onPressed: _gravarSemPet,
      ),
    );
  }
}