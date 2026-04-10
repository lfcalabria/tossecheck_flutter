import 'package:flutter/material.dart';
import '../models/observacao.dart';

class DetalhesObservacaoScreen extends StatelessWidget {
  final Observacao observacao;

  const DetalhesObservacaoScreen({
    super.key,
    required this.observacao,
  });

  String _formatarData(DateTime data) {
    final d = data.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final nomeVet = observacao.veterinario.trim().isEmpty
        ? 'Veterinário'
        : 'Dr(a). ${observacao.veterinario}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagem do Veterinário'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data: ${_formatarData(observacao.dataCadastro)}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Veterinário: $nomeVet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 40, thickness: 2),
            const Text(
              'Observação Clínica:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  observacao.mensagem,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}