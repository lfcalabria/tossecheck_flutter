import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/pet.dart';

class SelecionarPetVideoScreen extends StatefulWidget {
  final String videoPath;

  const SelecionarPetVideoScreen({Key? key, required this.videoPath}) : super(key: key);

  @override
  _SelecionarPetVideoScreenState createState() => _SelecionarPetVideoScreenState();
}

class _SelecionarPetVideoScreenState extends State<SelecionarPetVideoScreen> {
  List<Pet> _pets = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarPets();
  }

  Future<void> _carregarPets() async {
    _pets = await DatabaseHelper.instance.getPets();
    setState(() => _carregando = false);
  }

  Future<void> _salvarEvento(Pet pet) async {
    try {
      final eventoUuid = const Uuid().v4();
      
      // Aqui você vai chamar o seu método real de salvar o Histórico/Gravação no banco
      // Substitua pela sua função exata do DatabaseHelper (ex: insertHistorico)
      await DatabaseHelper.instance.insertHistorico(
        uuid: eventoUuid,
        petId: pet.id!, 
        caminhoVideo: widget.videoPath,
        dataHora: DateTime.now().toIso8601String(),
        sincronizado: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vídeo salvo com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Fecha a tela de seleção e volta para a Home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar vídeo.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quem tossiu?')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _pets.isEmpty
              ? const Center(child: Text('Nenhum pet encontrado.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pets.length,
                  itemBuilder: (context, index) {
                    final pet = _pets[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.teal.shade100,
                          backgroundImage: pet.fotoPath != null ? FileImage(File(pet.fotoPath!)) : null,
                          child: pet.fotoPath == null
                              ? Icon(pet.tipo == 'gato' ? Icons.pets : Icons.pets, color: Colors.teal)
                              : null,
                        ),
                        title: Text(pet.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text(pet.tipo),
                        trailing: const Icon(Icons.check_circle_outline, color: Colors.teal, size: 30),
                        onTap: () => _salvarEvento(pet),
                      ),
                    );
                  },
                ),
    );
  }
}