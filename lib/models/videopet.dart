class VideoPet {
  int? id;
  String? uuid;
  int? petId; // Adicionado para funcionar offline
  String? petUuid;
  String caminhoLocal;
  String? urlServidor;
  DateTime dataCadastro;
  DateTime dataUltimaAtualizacao;
  bool sincronizado;

  VideoPet({
    this.id,
    this.uuid,
    this.petId,
    this.petUuid,
    required this.caminhoLocal,
    this.urlServidor,
    required this.dataCadastro,
    required this.dataUltimaAtualizacao,
    this.sincronizado = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'uuid': uuid,
    'pet_id': petId,
    'pet_uuid': petUuid,
    'caminho_local': caminhoLocal,
    'url_servidor': urlServidor,
    'data_cadastro': dataCadastro.toIso8601String(),
    'data_ultima_atualizacao': dataUltimaAtualizacao.toIso8601String(),
    'sincronizado': sincronizado ? 1 : 0,
  };

  factory VideoPet.fromMap(Map<String, dynamic> map) => VideoPet(
    id: map['id'],
    uuid: map['uuid'],
    petId: map['pet_id'],
    petUuid: map['pet_uuid'],
    caminhoLocal: map['caminho_local'],
    urlServidor: map['url_servidor'],
    dataCadastro: DateTime.parse(map['data_cadastro']),
    dataUltimaAtualizacao: DateTime.parse(map['data_ultima_atualizacao']),
    sincronizado: map['sincronizado'] == 1,
  );
}