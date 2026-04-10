class Observacao {
  int? id;
  String? uuid;

  /// ✅ Agora observação pertence ao PET (alinhado com backend e SQLite)
  String petUuid;

  /// Nome do veterinário (texto) – no Flutter você pode armazenar só o nome
  String veterinario;

  String mensagem;

  DateTime dataCadastro;
  DateTime dataUltimaAtualizacao;

  /// Observação normalmente vem do veterinário (sincronizado = true)
  bool sincronizado;

  Observacao({
    this.id,
    this.uuid,
    required this.petUuid,
    required this.veterinario,
    required this.mensagem,
    required this.dataCadastro,
    required this.dataUltimaAtualizacao,
    this.sincronizado = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'pet_uuid': petUuid,
        'veterinario': veterinario,
        'mensagem': mensagem,
        'data_cadastro': dataCadastro.toIso8601String(),
        'data_ultima_atualizacao': dataUltimaAtualizacao.toIso8601String(),
        'sincronizado': sincronizado ? 1 : 0,
      };

  factory Observacao.fromMap(Map<String, dynamic> map) => Observacao(
        id: map['id'] as int?,
        uuid: map['uuid'] as String?,
        petUuid: (map['pet_uuid'] ?? '').toString(),
        veterinario: (map['veterinario'] ?? '').toString(),
        mensagem: (map['mensagem'] ?? '').toString(),
        dataCadastro: DateTime.parse(map['data_cadastro'].toString()),
        dataUltimaAtualizacao: DateTime.parse(map['data_ultima_atualizacao'].toString()),
        sincronizado: (map['sincronizado'] ?? 1) == 1,
      );
}