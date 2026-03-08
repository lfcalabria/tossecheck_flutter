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
    // Atualizado para versão 2 para aplicar as mudanças de offline
    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _createDB, 
      onUpgrade: _onUpgrade
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT, nome TEXT NOT NULL,
        cpf TEXT NOT NULL, telefone TEXT NOT NULL, data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL, sincronizado INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE pets (
        id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT, usuario_uuid TEXT,
        nome TEXT NOT NULL, tipo TEXT NOT NULL, sexo TEXT NOT NULL,
        raca TEXT NOT NULL, idade INTEGER NOT NULL, peso REAL NOT NULL,
        altura REAL NOT NULL, foto_path TEXT, data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL, sincronizado INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE videos (
        id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT, pet_id INTEGER, pet_uuid TEXT,
        caminho_local TEXT NOT NULL, url_servidor TEXT, data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL, sincronizado INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE observacoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT, video_uuid TEXT,
        veterinario TEXT NOT NULL, mensagem TEXT NOT NULL, data_cadastro TEXT NOT NULL,
        data_ultima_atualizacao TEXT NOT NULL, sincronizado INTEGER DEFAULT 1
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Adiciona a coluna para quem já tinha o app instalado
      await db.execute('ALTER TABLE videos ADD COLUMN pet_id INTEGER');
    }
  }

  // --- MÉTODOS DE USUÁRIO ---
  Future<Usuario?> getUsuario() async {
    final db = await instance.database;
    final maps = await db.query('usuarios', limit: 1);
    if (maps.isNotEmpty) return Usuario.fromMap(maps.first);
    return null;
  }
  Future<int> insertUsuario(Usuario usuario) async {
    final db = await instance.database;
    return await db.insert('usuarios', usuario.toMap());
  }
  Future<int> updateUsuario(Usuario usuario) async {
    final db = await instance.database;
    return await db.update('usuarios', usuario.toMap(), where: 'id = ?', whereArgs: [usuario.id]);
  }

  // --- MÉTODOS DE PETS ---
  Future<List<Pet>> getPets() async {
    final db = await instance.database;
    final maps = await db.query('pets', orderBy: 'nome ASC');
    return maps.map((m) => Pet.fromMap(m)).toList();
  }
  Future<int> insertPet(Pet pet) async {
    final db = await instance.database;
    return await db.insert('pets', pet.toMap());
  }
  Future<int> updatePet(Pet pet) async {
    final db = await instance.database;
    return await db.update('pets', pet.toMap(), where: 'id = ?', whereArgs: [pet.id]);
  }

  // --- MÉTODOS DE VÍDEOS ---
  // Busca offline usando o ID local do pet
  Future<List<VideoPet>> getVideosPorPetId(int petId) async {
    final db = await instance.database;
    final maps = await db.query('videos', where: 'pet_id = ?', whereArgs: [petId], orderBy: 'data_cadastro DESC');
    return maps.map((m) => VideoPet.fromMap(m)).toList();
  }
  
  Future<int> insertVideo(VideoPet video) async {
    final db = await instance.database;
    return await db.insert('videos', video.toMap());
  }
  Future<int> updateVideo(VideoPet video) async {
    final db = await instance.database;
    return await db.update('videos', video.toMap(), where: 'id = ?', whereArgs: [video.id]);
  }

  // --- MÉTODOS DE OBSERVAÇÕES ---
  Future<List<Observacao>> getObservacoes() async {
    final db = await instance.database;
    final maps = await db.query('observacoes', orderBy: 'data_cadastro DESC');
    return maps.map((m) => Observacao.fromMap(m)).toList();
  }
  
  Future<List<Observacao>> getObservacoesPorVideoUuid(String videoUuid) async {
    final db = await instance.database;
    final maps = await db.query('observacoes', where: 'video_uuid = ?', whereArgs: [videoUuid], orderBy: 'data_cadastro DESC');
    return maps.map((m) => Observacao.fromMap(m)).toList();
  }

  Future<int> insertObservacao(Observacao observacao) async {
    final db = await instance.database;
    return await db.insert('observacoes', observacao.toMap());
  }

  // --- MÉTODOS DE SINCRONIZAÇÃO ---
  Future<List<Map<String, dynamic>>> getPendentes(String table) async {
    final db = await instance.database;
    return await db.query(table, where: 'sincronizado = 0');
  }
}