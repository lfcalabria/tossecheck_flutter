import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../database/database_helper.dart';
import '../models/pet.dart';
import '../models/videopet.dart';
import '../models/observacao.dart';
import '../services/api_service.dart';
import 'reproduzir_video_screen.dart';
import 'detalhes_observacao_screen.dart';

class EditarPetScreen extends StatefulWidget {
  final Pet pet;
  const EditarPetScreen({super.key, required this.pet});

  @override
  State<EditarPetScreen> createState() => _EditarPetScreenState();
}

class _EditarPetScreenState extends State<EditarPetScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomeController;
  late TextEditingController _racaController;
  late TextEditingController _idadeController;
  late TextEditingController _pesoController;
  late TextEditingController _alturaController;

  List<VideoPet> _videos = [];
  List<Observacao> _observacoes = [];

  String? _fotoPath;
  bool _salvando = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _nomeController = TextEditingController(text: widget.pet.nome);
    _racaController = TextEditingController(text: widget.pet.raca ?? '');
    _idadeController = TextEditingController(text: widget.pet.idade?.toString() ?? '');
    _pesoController = TextEditingController(text: widget.pet.peso?.toString() ?? '');
    _alturaController = TextEditingController(text: widget.pet.altura?.toString() ?? '');

    _fotoPath = widget.pet.fotoPath;

    _carregarListas();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _racaController.dispose();
    _idadeController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    super.dispose();
  }

  Future<void> _carregarListas() async {
    // Vídeos: dependem do pet.id (offline)
    if (widget.pet.id != null) {
      _videos = await DatabaseHelper.instance.getVideosPorPetId(widget.pet.id!);
    } else {
      _videos = [];
    }

    // ✅ Observações agora são por PET_UUID (não por vídeo)
    // Se o pet ainda não tem uuid (não sincronizado), não há observações do veterinário para ele.
    if (widget.pet.uuid != null && widget.pet.uuid!.isNotEmpty) {
      _observacoes = await DatabaseHelper.instance.getObservacoesPorPetUuid(widget.pet.uuid!);
    } else {
      _observacoes = [];
    }

    if (mounted) setState(() {});
  }

  String _formatarNome(String texto) {
    if (texto.trim().isEmpty) return '';
    return texto.trim().split(RegExp(r'\s+')).map((palavra) {
      if (palavra.isEmpty) return '';
      if (['de', 'da', 'das', 'do', 'dos', 'e'].contains(palavra.toLowerCase())) {
        return palavra.toLowerCase();
      }
      return palavra[0].toUpperCase() + palavra.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _capturarFoto(ImageSource source) async {
    final XFile? foto = await _picker.pickImage(source: source, imageQuality: 80);
    if (foto != null) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'pet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String newPath = path.join(appDir.path, fileName);
      await File(foto.path).copy(newPath);
      setState(() => _fotoPath = newPath);
    }
  }

  void _mostrarOpcoesFoto() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () {
                Navigator.pop(context);
                _capturarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Galeria'),
              onTap: () {
                Navigator.pop(context);
                _capturarFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      // Converte números de forma segura (agora Pet aceita null)
      final idadeTxt = _idadeController.text.trim();
      final pesoTxt = _pesoController.text.trim().replaceAll(',', '.');
      final alturaTxt = _alturaController.text.trim().replaceAll(',', '.');

      final idade = idadeTxt.isEmpty ? null : int.tryParse(idadeTxt);
      final peso = pesoTxt.isEmpty ? null : double.tryParse(pesoTxt);
      final altura = alturaTxt.isEmpty ? null : double.tryParse(alturaTxt);

      // Atualiza objeto do pet
      widget.pet.nome = _formatarNome(_nomeController.text);
      widget.pet.raca = _racaController.text.trim().isEmpty ? null : _formatarNome(_racaController.text);
      widget.pet.idade = idade;
      widget.pet.peso = peso;
      widget.pet.altura = altura;

      widget.pet.fotoPath = _fotoPath;
      widget.pet.dataUltimaAtualizacao = DateTime.now();
      widget.pet.sincronizado = false;

      await DatabaseHelper.instance.updatePet(widget.pet);

      // Tenta sincronizar (se tiver internet, envia alterações e pendências)
      await ApiService().sincronizarGeral();

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarVideos() {
    if (_videos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum vídeo gravado ainda para este pet.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: _videos.length,
        itemBuilder: (ctx, i) {
          final data = _videos[i].dataCadastro.toLocal().toString().split(' ')[0];
          return ListTile(
            leading: const Icon(Icons.video_library, color: Colors.teal),
            title: Text('Vídeo de $data'),
            trailing: _videos[i].sincronizado
                ? const Icon(Icons.cloud_done, color: Colors.green)
                : const Icon(Icons.cloud_upload, color: Colors.orange),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReproduzirVideoScreen(video: _videos[i])),
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarObservacoes() {
    if (_observacoes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma observação recebida ainda.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: _observacoes.length,
        itemBuilder: (ctx, i) {
          return ListTile(
            leading: const Icon(Icons.medical_information, color: Colors.teal),
            title: Text('Vet: Dr(a). ${_observacoes[i].veterinario}'),
            subtitle: const Text('Toque para ler'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalhesObservacaoScreen(observacao: _observacoes[i]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Pet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _mostrarOpcoesFoto,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: _fotoPath != null ? FileImage(File(_fotoPath!)) : null,
                  child: _fotoPath == null
                      ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _racaController,
                decoration: const InputDecoration(labelText: 'Raça', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _idadeController,
                      decoration: const InputDecoration(labelText: 'Idade', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _pesoController,
                      decoration: const InputDecoration(labelText: 'Peso', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _alturaController,
                      decoration: const InputDecoration(labelText: 'Altura', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                icon: const Icon(Icons.video_collection, color: Colors.white),
                label: Text('Ver Vídeos (${_videos.length})',
                    style: const TextStyle(color: Colors.white)),
                onPressed: _mostrarVideos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 10),

              ElevatedButton.icon(
                icon: const Icon(Icons.message, color: Colors.teal),
                label: Text('Ver Observações (${_observacoes.length})',
                    style: const TextStyle(color: Colors.teal)),
                onPressed: _mostrarObservacoes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade50,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _salvando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Salvar Alterações',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}