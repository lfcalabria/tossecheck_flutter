import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/pet.dart';
import '../models/videopet.dart';
import '../services/api_service.dart';
import 'cadastro_pet_screen.dart';

class SelecionarPetVideoScreen extends StatefulWidget {
  final String videoPath;
  const SelecionarPetVideoScreen({super.key, required this.videoPath});

  @override
  State<SelecionarPetVideoScreen> createState() => _SelecionarPetVideoScreenState();
}

class _SelecionarPetVideoScreenState extends State<SelecionarPetVideoScreen> {
  List<Pet> _pets = [];
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final p = await DatabaseHelper.instance.getPets();
    if (!mounted) return;
    setState(() => _pets = p);
  }

  Future<int?> _resolverPetIdLocal(Pet pet) async {
    // Se já vier com id, beleza
    if (pet.id != null) return pet.id;

    // Se não tiver id, tenta achar no banco pelo uuid (caso exista)
    if (pet.uuid != null && pet.uuid!.isNotEmpty) {
      final petNoDb = await DatabaseHelper.instance.getPetPorUuid(pet.uuid!);
      return petNoDb?.id;
    }

    // Sem id e sem uuid, não dá para resolver
    return null;
  }

  Future<void> _vincular(Pet pet) async {
    if (_salvando) return;
    setState(() => _salvando = true);

    try {
      final agora = DateTime.now();
      final petIdLocal = await _resolverPetIdLocal(pet);

      // Se não conseguimos id local e o pet não tem uuid, não dá para vincular com segurança
      // (caso raro, mas evita crash)
      if (petIdLocal == null && (pet.uuid == null || pet.uuid!.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível identificar o pet localmente. Tente abrir o pet na lista e salvar.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final video = VideoPet(
        uuid: const Uuid().v4(),
        petId: petIdLocal,          // ✅ pode ser null
        petUuid: pet.uuid,          // ✅ pode ser null (vai sincronizar depois)
        caminhoLocal: widget.videoPath,
        dataCadastro: agora,
        dataUltimaAtualizacao: agora,
        sincronizado: false,
      );

      await DatabaseHelper.instance.insertVideo(video);

      // ✅ opcional, mas recomendado: tenta sincronizar já
      await ApiService().sincronizarGeral();

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quem tossiu?"),
        actions: [
          if (_salvando)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
        ],
      ),
      body: _pets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Nenhum pet cadastrado."),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CadastroPetScreen()),
                      );
                      await _carregar();
                    },
                    child: const Text("Cadastrar Pet Agora"),
                  )
                ],
              ),
            )
          : ListView.builder(
              itemCount: _pets.length,
              itemBuilder: (context, index) {
                final pet = _pets[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.pets),
                  ),
                  title: Text(pet.nome),
                  subtitle: Text((pet.raca == null || pet.raca!.trim().isEmpty) ? 'Raça não informada' : pet.raca!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _salvando ? null : () => _vincular(pet),
                );
              },
            ),

      // Se a lista NÃO estiver vazia, mostramos um botão flutuante para cadastrar mais pets
      floatingActionButton: _pets.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CadastroPetScreen()),
                );
                await _carregar();
              },
              icon: const Icon(Icons.add),
              label: const Text("Novo Pet"),
            )
          : null,
    );
  }
}
