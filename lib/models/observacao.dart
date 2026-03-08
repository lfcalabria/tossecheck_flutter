class Observacao {
  int? id;
  String? uuid;
  String? videoUuid;
  String veterinario;
  String mensagem;
  DateTime dataCadastro;
  DateTime dataUltimaAtualizacao;
  bool sincronizado;

  Observacao({
    this.id, this.uuid, this.videoUuid, required this.veterinario, required this.mensagem,
    required this.dataCadastro, required this.dataUltimaAtualizacao, this.sincronizado = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'uuid': uuid, 'video_uuid': videoUuid, 'veterinario': veterinario, 'mensagem': mensagem,
    'data_cadastro': dataCadastro.toIso8601String(),
    'data_ultima_atualizacao': dataUltimaAtualizacao.toIso8601String(),
    'sincronizado': sincronizado ? 1 : 0,
  };

  factory Observacao.fromMap(Map<String, dynamic> map) => Observacao(
    id: map['id'], uuid: map['uuid'], videoUuid: map['video_uuid'], veterinario: map['veterinario'],
    mensagem: map['mensagem'], dataCadastro: DateTime.parse(map['data_cadastro']),
    dataUltimaAtualizacao: DateTime.parse(map['data_ultima_atualizacao']),
    sincronizado: map['sincronizado'] == 1,
  );
}