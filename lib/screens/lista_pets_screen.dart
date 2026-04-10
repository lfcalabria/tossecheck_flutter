import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // IMPORT NOVO
import '../database/database_helper.dart';
import '../models/usuario.dart';
import '../models/pet.dart';
import '../services/api_service.dart';
import 'cadastro_pet_screen.dart';
import 'editar_pet_screen.dart';
import 'gravar_video_screen.dart';
import 'selecionar_pet_video_screen.dart'; // TELA NOVA QUE VAMOS CRIAR ABAIXO

class ListaPetsScreen extends StatefulWidget {
  const ListaPetsScreen({super.key});

  @override
  _ListaPetsScreenState createState() => _ListaPetsScreenState();
}

class _ListaPetsScreenState extends State<ListaPetsScreen> {
  Usuario? _usuario;
  List<Pet> _pets = [];
  bool _sincronizando = false;
  
  // Instância do ImagePicker para abrir a câmera
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _carregarDados();
    
    // Diz para a API atualizar essa tela automaticamente quando terminar o sync em background
    ApiService().onSyncComplete = () {
      if (mounted) _carregarDados();
    };
  }

  @override
  void dispose() {
    // Remove o listener quando a tela for fechada
    ApiService().onSyncComplete = null;
    super.dispose();
  }

  Future<void> _carregarDados() async {
    _usuario = await DatabaseHelper.instance.getUsuario();
    _pets = await DatabaseHelper.instance.getPets();
    if (mounted) setState(() {});
  }

  Future<void> _sincronizarManual() async {
    setState(() => _sincronizando = true);
    await ApiService().sincronizarGeral();
    await _carregarDados();
    setState(() => _sincronizando = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronização concluída!'), backgroundColor: Colors.green),
      );
    }
  }

  // NOVA FUNÇÃO: Abre a câmera e vai para a tela de seleção
  Future<void> _abrirCamera() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );

      if (video != null && mounted) {
        // Redireciona para a tela que vincula o vídeo ao pet
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelecionarPetVideoScreen(videoPath: video.path),
          ),
        );
        // Ao voltar, recarrega a lista
        _carregarDados();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao acessar a câmera.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${_usuario?.primeiroNome ?? ""}'),
        actions: [
          // MOVIDO: Botão de adicionar pet agora fica na AppBar
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Adicionar novo pet',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroPetScreen()));
              _carregarDados();
            },
          ),
          if (_sincronizando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _sincronizando ? null : _sincronizarManual,
            tooltip: 'Sincronizar dados',
          ),
        ],
      ),
      body: _pets.isEmpty
          ? const Center(
              child: Text('Nenhum pet cadastrado. Toque no + para adicionar.', 
              style: TextStyle(fontSize: 16, color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80), // Espaço pro botão não cobrir itens
              itemCount: _pets.length,
              itemBuilder: (context, index) {
                final pet = _pets[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () {
                      // Mantido o fluxo antigo caso a pessoa queira clicar no pet primeiro
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GravarVideoScreen(pet: pet),
                      ));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.teal.shade100,
                            backgroundImage: pet.fotoPath != null ? FileImage(File(pet.fotoPath!)) : null,
                            child: pet.fotoPath == null
                                ? Icon(pet.tipo == 'gato' ? Icons.pets : Icons.pets, size: 35, color: Colors.teal)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pet.nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('${pet.tipo} • ${pet.raca}', style: TextStyle(color: Colors.grey.shade700)),
                                if (!pet.sincronizado)
                                  const Text('Pendente de sincronização', style: TextStyle(color: Colors.orange, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.teal),
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => EditarPetScreen(pet: pet),
                              ));
                              _carregarDados();
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      // NOVO: Botão de gravar tosse em destaque
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.videocam, color: Colors.white, size: 28),
        label: const Text('GRAVAR TOSSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _abrirCamera,
      ),
    );
  }
}