// lib/models/question.dart

class Question {
  final int? id;         // DB保存用のID（新規作成時はnull）
  final String subject;  // 科目（例: 企業法）
  final String topic;    // 論点（例: 機関）
  final String text;     // 問題文
  final bool isCorrect;  // 正誤
  final String explanation; // 解説

  Question({
    this.id,
    required this.subject,
    required this.topic,
    required this.text,
    required this.isCorrect,
    required this.explanation,
  });

  // UI表示用に科目と論点を結合するゲッター（例：【企業法】機関）
  String get category => '【$subject】$topic';

  // DartのオブジェクトをSQLite保存用のMap（辞書型）に変換する
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'topic': topic,
      'text': text,
      'is_correct': isCorrect ? 1 : 0, // SQLiteはboolがないので0と1で保存
      'explanation': explanation,
    };
  }

  // SQLiteから取り出したMapをDartのオブジェクトに変換する
  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'],
      subject: map['subject'],
      topic: map['topic'],
      text: map['text'],
      isCorrect: map['is_correct'] == 1,
      explanation: map['explanation'],
    );
  }
}