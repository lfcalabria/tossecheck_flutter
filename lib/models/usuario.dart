class Usuario {
  int? id;
  String? uuid;

  String nome;
  String cpf;
  String telefone;

  DateTime dataCadastro;
  DateTime dataUltimaAtualizacao;

  bool sincronizado;
  bool bloqueado;
  bool liberado;

  Usuario({
    this.id,
    this.uuid,
    required this.nome,
    required this.cpf,
    required this.telefone,
    required this.dataCadastro,
    required this.dataUltimaAtualizacao,
    this.sincronizado = false,
    this.bloqueado = false,
    this.liberado = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'uuid': uuid,
        'nome': nome,
        'cpf': cpf,
        'telefone': telefone,
        'data_cadastro': dataCadastro.toIso8601String(),
        'data_ultima_atualizacao': dataUltimaAtualizacao.toIso8601String(),
        'sincronizado': sincronizado ? 1 : 0,
        'bloqueado': bloqueado ? 1 : 0,
        'liberado': liberado ? 1 : 0,
      };

  factory Usuario.fromMap(Map<String, dynamic> map) => Usuario(
        id: map['id'] as int?,
        uuid: map['uuid']?.toString(),
        nome: (map['nome'] ?? '').toString(),
        cpf: (map['cpf'] ?? '').toString(),
        telefone: (map['telefone'] ?? '').toString(),
        dataCadastro: map['data_cadastro'] != null
            ? DateTime.parse(map['data_cadastro'].toString())
            : DateTime.now(),
        dataUltimaAtualizacao: map['data_ultima_atualizacao'] != null
            ? DateTime.parse(map['data_ultima_atualizacao'].toString())
            : DateTime.now(),
        sincronizado: (map['sincronizado'] ?? 0) == 1,
        bloqueado: (map['bloqueado'] ?? 0) == 1,
        liberado: (map['liberado'] ?? 1) == 1,
      );

  /// Apenas o primeiro nome (para UI)
  String get primeiroNome =>
      nome.trim().isEmpty ? '' : nome.trim().split(' ').first;
}