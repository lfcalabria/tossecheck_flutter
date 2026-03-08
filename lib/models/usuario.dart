class Usuario {
  int? id;
  String? uuid;
  String nome;
  String cpf;
  String telefone;
  DateTime dataCadastro;
  DateTime dataUltimaAtualizacao;
  bool sincronizado;

  Usuario({
    this.id, this.uuid, required this.nome, required this.cpf, required this.telefone,
    required this.dataCadastro, required this.dataUltimaAtualizacao, this.sincronizado = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'uuid': uuid, 'nome': nome, 'cpf': cpf, 'telefone': telefone,
    'data_cadastro': dataCadastro.toIso8601String(),
    'data_ultima_atualizacao': dataUltimaAtualizacao.toIso8601String(),
    'sincronizado': sincronizado ? 1 : 0,
  };

  factory Usuario.fromMap(Map<String, dynamic> map) => Usuario(
    id: map['id'], uuid: map['uuid'], nome: map['nome'], cpf: map['cpf'], telefone: map['telefone'],
    dataCadastro: DateTime.parse(map['data_cadastro']),
    dataUltimaAtualizacao: DateTime.parse(map['data_ultima_atualizacao']),
    sincronizado: map['sincronizado'] == 1,
  );

  String get primeiroNome => nome.split(' ').first;
}

