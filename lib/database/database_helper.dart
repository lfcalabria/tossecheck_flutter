import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/usuario.dart';
import '../models/pet.dart';
import '../models/videopet.dart';
import '../models/observacao.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tossecheck.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        nome TEXT NOT NULL,
        cpf TEXT NOT NULL,
        telefone TEXT NOT NULL,
        data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0,
        bloqueado INTEGER DEFAULT 0,
        liberado INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE pets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        usuario_uuid TEXT,
        nome TEXT NOT NULL,
        tipo TEXT NOT NULL,
        sexo TEXT NOT NULL,
        raca TEXT NOT NULL,
        idade INTEGER NOT NULL,
        peso REAL NOT NULL,
        altura REAL NOT NULL,
        foto_path TEXT,
        data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        pet_id INTEGER,
        pet_uuid TEXT,
        caminho_local TEXT NOT NULL,
        url_servidor TEXT,
        data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE observacoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        pet_uuid TEXT NOT NULL,
        veterinario TEXT NOT NULL,
        mensagem TEXT NOT NULL,
        data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL,
        sincronizado INTEGER DEFAULT 1
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE videos ADD COLUMN pet_id INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE usuarios ADD COLUMN sincronizado INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE pets ADD COLUMN sincronizado INTEGER DEFAULT 0'); } catch (_) {}
    }

    if (oldVersion < 3) {
      try { await db.execute('ALTER TABLE usuarios ADD COLUMN bloqueado INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE usuarios ADD COLUMN liberado INTEGER DEFAULT 1'); } catch (_) {}
    }

    if (oldVersion < 4) {
      // mantém sua migração original se existir em outra versão;
      // aqui não forçamos drop/rename para não perder dados.
    }
  }

  // =========================
  // USUÁRIO
  // =========================

  Future<Usuario?> getUsuario() async {
    final db = await instance.database;
    final maps = await db.query('usuarios', limit: 1);
    if (maps.isNotEmpty) return Usuario.fromMap(maps.first);
    return null;
  }

  Future<Usuario?> getUsuarioPorCpf(String cpf) async {
    final db = await instance.database;
    final maps = await db.query(
      'usuarios',
      where: 'cpf = ?',
      whereArgs: [cpf],
      limit: 1,
    );
    if (maps.isNotEmpty) return Usuario.fromMap(maps.first);
    return null;
  }

  Future<int> insertUsuario(Usuario usuario) async {
    final db = await instance.database;
    return await db.insert('usuarios', usuario.toMap());
  }

  Future<int> updateUsuario(Usuario usuario) async {
    final db = await instance.database;
    return await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  Future<int> updateUsuarioPorUuid(Usuario usuario) async {
    final db = await instance.database;
    return await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'uuid = ?',
      whereArgs: [usuario.uuid],
    );
  }

  Future<int> marcarUsuarioBloqueado({required String? uuid, required int? id}) async {
    final db = await instance.database;
    return await db.update(
      'usuarios',
      {
        'bloqueado': 1,
        'liberado': 0,
        'sincronizado': 0,
        'data_ultima_atualizacao': DateTime.now().toIso8601String(),
      },
      where: uuid != null ? 'uuid = ?' : 'id = ?',
      whereArgs: [uuid ?? id],
    );
  }

  Future<int> marcarUsuarioLiberado({required String? uuid, required int? id}) async {
    final db = await instance.database;
    return await db.update(
      'usuarios',
      {
        'bloqueado': 0,
        'liberado': 1,
        'sincronizado': 1,
        'data_ultima_atualizacao': DateTime.now().toIso8601String(),
      },
      where: uuid != null ? 'uuid = ?' : 'id = ?',
      whereArgs: [uuid ?? id],
    );
  }

  // ✅ Atualização canônica com dados do backend
  Future<int> atualizarUsuarioComDadosDoBackend({
    required String cpf,
    required String uuid,
    required String nome,
    required String telefone,
    required bool bloqueado,
    required bool liberado,
  }) async {
    final db = await instance.database;
    return await db.update(
      'usuarios',
      {
        'uuid': uuid,
        'nome': nome,
        'telefone': telefone,
        'bloqueado': bloqueado ? 1 : 0,
        'liberado': liberado ? 1 : 0,
        'sincronizado': liberado ? 1 : 0,
        'data_ultima_atualizacao': DateTime.now().toIso8601String(),
      },
      where: 'cpf = ?',
      whereArgs: [cpf],
    );
  }

  // =========================
  // PETS
  // =========================

  Future<List<Pet>> getPets() async {
    final db = await instance.database;
    final maps = await db.query('pets', orderBy: 'nome ASC');
    return maps.map((m) => Pet.fromMap(m)).toList();
  }

  Future<List<Pet>> getPetsPorUsuarioUuid(String usuarioUuid) async {
    final db = await instance.database;
    final maps = await db.query(
      'pets',
      where: 'usuario_uuid = ?',
      whereArgs: [usuarioUuid],
      orderBy: 'nome ASC',
    );
    return maps.map((m) => Pet.fromMap(m)).toList();
  }

  Future<Pet?> getPetPorUuid(String uuid) async {
    final db = await instance.database;
    final maps = await db.query(
      'pets',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (maps.isNotEmpty) return Pet.fromMap(maps.first);
    return null;
  }

  Future<Pet?> getPetPorId(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'pets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) return Pet.fromMap(maps.first);
    return null;
  }

  Future<int> insertPet(Pet pet) async {
    final db = await instance.database;
    return await db.insert('pets', pet.toMap());
  }

  Future<int> updatePet(Pet pet) async {
    final db = await instance.database;
    return await db.update(
      'pets',
      pet.toMap(),
      where: 'id = ?',
      whereArgs: [pet.id],
    );
  }

  Future<int> updatePetByUuid(Pet pet) async {
    final db = await instance.database;
    return await db.update(
      'pets',
      pet.toMap(),
      where: 'uuid = ?',
      whereArgs: [pet.uuid],
    );
  }

  // =========================
  // VÍDEOS
  // =========================

  Future<List<VideoPet>> getVideosPorPetId(int petId) async {
    final db = await instance.database;
    final maps = await db.query(
      'videos',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'data_cadastro DESC',
    );
    return maps.map((m) => VideoPet.fromMap(m)).toList();
  }

  Future<VideoPet?> getVideoPorUuid(String uuid) async {
    final db = await instance.database;
    final maps = await db.query(
      'videos',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (maps.isNotEmpty) return VideoPet.fromMap(maps.first);
    return null;
  }

  Future<int> insertVideo(VideoPet video) async {
    final db = await instance.database;
    return await db.insert('videos', video.toMap());
  }

  Future<int> updateVideo(VideoPet video) async {
    final db = await instance.database;
    return await db.update(
      'videos',
      video.toMap(),
      where: 'id = ?',
      whereArgs: [video.id],
    );
  }

  Future<void> upsertVideoPorUuid(VideoPet video) async {
    if (video.uuid == null) return;
    final existente = await getVideoPorUuid(video.uuid!);
    if (existente == null) {
      await insertVideo(video);
    } else {
      video.id = existente.id;
      await updateVideo(video);
    }
  }

  // =========================
  // OBSERVAÇÕES
  // =========================

  Future<List<Observacao>> getObservacoes() async {
    final db = await instance.database;
    final maps = await db.query('observacoes', orderBy: 'data_cadastro DESC');
    return maps.map((m) => Observacao.fromMap(m)).toList();
  }

  Future<List<Observacao>> getObservacoesPorPetUuid(String petUuid) async {
    final db = await instance.database;
    final maps = await db.query(
      'observacoes',
      where: 'pet_uuid = ?',
      whereArgs: [petUuid],
      orderBy: 'data_cadastro DESC',
    );
    return maps.map((m) => Observacao.fromMap(m)).toList();
  }

  Future<Observacao?> getObservacaoPorUuid(String uuid) async {
    final db = await instance.database;
    final maps = await db.query(
      'observacoes',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (maps.isNotEmpty) return Observacao.fromMap(maps.first);
    return null;
  }

  Future<int> insertObservacao(Observacao observacao) async {
    final db = await instance.database;
    return await db.insert('observacoes', observacao.toMap());
  }

  Future<void> upsertObservacaoPorUuid(Observacao obs) async {
    if (obs.uuid == null) return;
    final existente = await getObservacaoPorUuid(obs.uuid!);
    if (existente == null) {
      await insertObservacao(obs);
    } else {
      // Mantemos sem update para não depender de updateObservacao inexistente.
      // Se quiser update, podemos criar depois.
    }
  }

  // =========================
  // PENDENTES
  // =========================

  Future<List<Map<String, dynamic>>> getPendentes(String table) async {
    final db = await instance.database;
    return await db.query(table, where: 'sincronizado = 0');
  }
}