// lib/db/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/question.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cpa_questions.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE questions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject TEXT NOT NULL,
  topic TEXT NOT NULL,
  text TEXT NOT NULL,
  is_correct INTEGER NOT NULL,
  explanation TEXT NOT NULL
)
''');
  }

  Future<Question> insert(Question question) async {
    final db = await instance.database;
    final id = await db.insert('questions', question.toMap());
    return Question(
      id: id,
      subject: question.subject,
      topic: question.topic,
      text: question.text,
      isCorrect: question.isCorrect,
      explanation: question.explanation,
    );
  }

  Future<List<Question>> getAllQuestions() async {
    final db = await instance.database;
    final result = await db.query('questions');
    return result.map((json) => Question.fromMap(json)).toList();
  }

  // 【追加】問題を編集・上書きする
  Future<int> update(Question question) async {
    final db = await instance.database;
    return db.update(
      'questions',
      question.toMap(),
      where: 'id = ?',
      whereArgs: [question.id],
    );
  }

  // 【追加】問題を削除する
  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'questions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}