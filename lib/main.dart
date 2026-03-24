// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/question.dart';
import 'db/database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
  runApp(const CPALawApp());
}

class CPALawApp extends StatefulWidget {
  const CPALawApp({super.key});
  @override
  State<CPALawApp> createState() => _CPALawAppState();
}

class _CPALawAppState extends State<CPALawApp> {
  bool _isDarkMode = false;
  List<Question> _allQuestions = [];
  bool _isLoading = true;

  // 【進化】各パーツの個別カラーを管理するマップ
  Map<String, Color> _customColors = {
    'appBar': Colors.blue[100]!,
    'background': Colors.white,
    'drawer': Colors.white,
    'text': Colors.black87,
    'button': Colors.blue[100]!,
  };

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    final questions = await DatabaseHelper.instance.getAllQuestions();
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _allQuestions = questions;
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      
      // 保存された個別カラーを読み込む
      if (prefs.containsKey('color_appBar')) {
        _customColors = {
          'appBar': Color(prefs.getInt('color_appBar')!),
          'background': Color(prefs.getInt('color_background')!),
          'drawer': Color(prefs.getInt('color_drawer')!),
          'text': Color(prefs.getInt('color_text')!),
          'button': Color(prefs.getInt('color_button')!),
        };
      } else {
        _applyPreset(_isDarkMode); // 初回はプリセットを適用
      }
      _isLoading = false;
    });
  }

  // ダークモード切替時などに、綺麗な初期セットを適用する
  void _applyPreset(bool isDark) {
    setState(() {
      if (isDark) {
        _customColors = {
          'appBar': Colors.grey[900]!,
          'background': const Color(0xFF121212), // 真っ黒に近いグレー
          'drawer': Colors.grey[850]!,
          'text': Colors.white,
          'button': Colors.blueGrey[700]!,
        };
      } else {
        _customColors = {
          'appBar': Colors.blue[100]!,
          'background': Colors.white,
          'drawer': Colors.white,
          'text': Colors.black87,
          'button': Colors.blue[100]!,
        };
      }
    });
    _saveAllColors();
  }

  Future<void> _saveAllColors() async {
    final prefs = await SharedPreferences.getInstance();
    _customColors.forEach((key, color) {
      prefs.setInt('color_$key', color.value);
    });
  }

  Future<void> _refreshQuestionsSilently() async {
    final questions = await DatabaseHelper.instance.getAllQuestions();
    setState(() => _allQuestions = questions);
  }

  void _toggleTheme(bool isDark) async {
    setState(() => _isDarkMode = isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    _applyPreset(isDark); // テーマ切替時は色をリセットして綺麗に整える
  }

  void _updateSpecificColor(String key, Color newColor) {
    setState(() {
      _customColors[key] = newColor;
    });
    _saveAllColors();
  }

  @override
  Widget build(BuildContext context) {
    // 【魔法】ユーザーが決めた色をアプリ全体のテーマに強制適用する
    final customTheme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _customColors['background'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: _customColors['button']!,
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        surface: _customColors['background']!,
        onSurface: _customColors['text']!,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _customColors['appBar'],
        foregroundColor: _customColors['text'], // ヘッダーの文字色
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: _customColors['drawer'],
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: _customColors['text']),
        bodyMedium: TextStyle(color: _customColors['text']),
        titleLarge: TextStyle(color: _customColors['text']),
        titleMedium: TextStyle(color: _customColors['text']),
      ),
      listTileTheme: ListTileThemeData(
        textColor: _customColors['text'],
        iconColor: _customColors['text'],
      ),
      iconTheme: IconThemeData(color: _customColors['text']),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _customColors['button'],
        foregroundColor: _customColors['text'],
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _customColors['button'],
          foregroundColor: _customColors['text'],
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _customColors['background'],
      )
    );

    return MaterialApp(
      title: 'CPA 学習アプリ',
      theme: customTheme,
      home: _isLoading 
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : MainScreen(
              allQuestions: _allQuestions,
              isDarkMode: _isDarkMode,
              customColors: _customColors,
              onThemeChanged: _toggleTheme,
              onColorChanged: _updateSpecificColor,
              onRefreshRequested: _refreshQuestionsSilently,
            ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final List<Question> allQuestions;
  final bool isDarkMode;
  final Map<String, Color> customColors;
  final Function(bool) onThemeChanged;
  final Function(String, Color) onColorChanged;
  final Function() onRefreshRequested;

  const MainScreen({
    super.key, required this.allQuestions, required this.isDarkMode, 
    required this.customColors, required this.onThemeChanged, 
    required this.onColorChanged, required this.onRefreshRequested
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;
    String appBarTitle;

    switch (_selectedIndex) {
      case 1:
        currentScreen = QuestionFormScreen(onSuccess: widget.onRefreshRequested);
        appBarTitle = '問題を新規追加';
        break;
      case 2:
        currentScreen = SettingsScreen(
          isDarkMode: widget.isDarkMode, 
          customColors: widget.customColors,
          onThemeChanged: widget.onThemeChanged, 
          onColorChanged: widget.onColorChanged,
        );
        appBarTitle = '設定';
        break;
      case 0:
      default:
        currentScreen = SelectionScreen(allQuestions: widget.allQuestions, onRefreshRequested: widget.onRefreshRequested);
        appBarTitle = '出題範囲の選択';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(fontWeight: FontWeight.bold)), 
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: widget.customColors['appBar']), 
              child: Text(
                'CPA 学習アプリ', 
                style: TextStyle(color: widget.customColors['text'], fontSize: 24, fontWeight: FontWeight.bold)
              ),
            ),
            ListTile(leading: const Icon(Icons.home), title: const Text('ホーム（問題一覧）'), selected: _selectedIndex == 0, onTap: () => _onItemTapped(0)),
            ListTile(leading: const Icon(Icons.add_box), title: const Text('問題を追加'), selected: _selectedIndex == 1, onTap: () => _onItemTapped(1)),
            const Divider(),
            ListTile(leading: const Icon(Icons.settings), title: const Text('設定'), selected: _selectedIndex == 2, onTap: () => _onItemTapped(2)),
          ],
        ),
      ),
      body: currentScreen,
    );
  }
}

// ---------------------------------------------------
// 【進化】折りたたみ式で直感的な詳細設定画面
// ---------------------------------------------------
class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Map<String, Color> customColors;
  final Function(bool) onThemeChanged;
  final Function(String, Color) onColorChanged;

  const SettingsScreen({
    super.key, required this.isDarkMode, required this.customColors,
    required this.onThemeChanged, required this.onColorChanged
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ドロップダウンの選択肢
  final Map<String, String> _colorTargets = {
    'appBar': '上部ヘッダー (AppBar)',
    'background': 'アプリ背景色 (Background)',
    'drawer': 'メニュー背景 (Menu)',
    'text': '文字・アイコン (Text)',
    'button': 'ボタン類 (Button)',
  };

  // 初期選択はヘッダー
  String _selectedTarget = 'appBar';

  // 現在選ばれているパーツの色を更新する
  void _updateColor(double r, double g, double b) {
    final newColor = Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), 1.0);
    widget.onColorChanged(_selectedTarget, newColor);
  }

  @override
  Widget build(BuildContext context) {
    // スライダーの現在値（選ばれているパーツの色を取得）
    final currentColor = widget.customColors[_selectedTarget]!;
    final double r = currentColor.red.toDouble();
    final double g = currentColor.green.toDouble();
    final double b = currentColor.blue.toDouble();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        SwitchListTile(
          title: const Text('ダークモード', style: TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: const Text('ON/OFFを切り替えると、色が初期設定にリセットされます'), 
          secondary: const Icon(Icons.dark_mode),
          value: widget.isDarkMode, 
          onChanged: widget.onThemeChanged,
        ),
        const Divider(),
        
        // 【要望機能】折りたたみ式の詳細設定メニュー
        ExpansionTile(
          initiallyExpanded: false, // 最初から開いておく
          leading: const Icon(Icons.palette),
          title: const Text('色の詳細設定', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('各パーツの色を個別に変更します'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: DropdownButtonFormField<String>(
                value: _selectedTarget,
                decoration: const InputDecoration(labelText: '変更するパーツを選択', border: OutlineInputBorder()),
                items: _colorTargets.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (val) {
                  setState(() => _selectedTarget = val!);
                },
              ),
            ),
            // 現在の色のプレビュー
            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: const Center(child: Text('プレビュー', style: TextStyle(color: Colors.grey))),
            ),
            // RGBスライダー
            _buildColorSlider('赤 (Red)', r, Colors.red, (val) => _updateColor(val, g, b)),
            _buildColorSlider('緑 (Green)', g, Colors.green, (val) => _updateColor(r, val, b)),
            _buildColorSlider('青 (Blue)', b, Colors.blue, (val) => _updateColor(r, g, val)),
            const SizedBox(height: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildColorSlider(String label, double value, Color color, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: Slider(
              value: value, min: 0, max: 255,
              activeColor: color, inactiveColor: color.withOpacity(0.3),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------
// 以下の SelectionScreen, QuestionFormScreen, QuizScreen は機能変更なしのため省略せずそのまま記載
// ---------------------------------------------------
class SelectionScreen extends StatefulWidget {
  final List<Question> allQuestions;
  final Function() onRefreshRequested;
  const SelectionScreen({super.key, required this.allQuestions, required this.onRefreshRequested});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  final Set<int> selectedQuestionIds = {};

  bool? _getCategoryCheckboxState(List<Question> questionsInCategory) {
    if (questionsInCategory.isEmpty) return false;
    int selectedCount = questionsInCategory.where((q) => selectedQuestionIds.contains(q.id)).length;
    if (selectedCount == 0) return false;
    if (selectedCount == questionsInCategory.length) return true;
    return null; 
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allQuestions.isEmpty) return const Center(child: Text('まだ問題がありません。\nメニューから問題を追加してください。', textAlign: TextAlign.center));

    final Map<String, List<Question>> groupedQuestions = {};
    for (var q in widget.allQuestions) {
      groupedQuestions.putIfAbsent(q.category, () => []).add(q);
    }
    final sortedCategories = groupedQuestions.keys.toList()..sort();

    return Scaffold(
      body: ListView.builder(
        itemCount: sortedCategories.length,
        itemBuilder: (context, index) {
          final category = sortedCategories[index];
          final questionsInCategory = groupedQuestions[category]!;
          final categoryCheckboxState = _getCategoryCheckboxState(questionsInCategory);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ExpansionTile(
              title: Row(
                children: [
                  Checkbox(
                    value: categoryCheckboxState,
                    tristate: true, 
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true || value == null) {
                          selectedQuestionIds.addAll(questionsInCategory.map((q) => q.id!));
                        } else {
                          selectedQuestionIds.removeAll(questionsInCategory.map((q) => q.id!));
                        }
                      });
                    },
                  ),
                  Expanded(child: Text(category, style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
              children: questionsInCategory.map((q) {
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                  leading: Checkbox(
                    value: selectedQuestionIds.contains(q.id),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) selectedQuestionIds.add(q.id!);
                        else selectedQuestionIds.remove(q.id!);
                      });
                    },
                  ),
                  title: Text(q.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(title: const Text('問題の編集')),
                            body: QuestionFormScreen(
                              questionToEdit: q, 
                              onSuccess: () {
                                Navigator.pop(context); 
                                widget.onRefreshRequested(); 
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: selectedQuestionIds.isEmpty
            ? null
            : () {
                final filteredQuestions = widget.allQuestions.where((q) => selectedQuestionIds.contains(q.id)).toList();
                filteredQuestions.shuffle();
                Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(questions: filteredQuestions)));
              },
        label: const Text('学習スタート'), icon: const Icon(Icons.play_arrow),
      ),
    );
  }
}

class QuestionFormScreen extends StatefulWidget {
  final Function() onSuccess;
  final Question? questionToEdit; 

  const QuestionFormScreen({super.key, required this.onSuccess, this.questionToEdit});

  @override
  State<QuestionFormScreen> createState() => _QuestionFormScreenState();
}

class _QuestionFormScreenState extends State<QuestionFormScreen> {
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  
  bool _isCorrect = true;
  bool _isSaved = false;

  final Map<String, List<String>> _subjectTopics = {
    '企業法': ['会社法総論', '機関', '株式', '設立', '資金調達', '株式会社の計算等', '組織再編行為等', '商行為法', '金融商品取引法'],
    '財務会計論': ['概念フレームワーク', '棚卸資産', '有形固定資産', '減損会計', 'リース会計', '連結会計'],
    '管理会計論': ['CVP分析', '標準原価計算', '直接原価計算', '意思決定会計'],
    '監査論': ['監査主体論', '監査実施論', '監査報告論', '監査基準'],
  };

  late String _selectedSubject;
  late String _selectedTopic;

  @override
  void initState() {
    super.initState();
    if (widget.questionToEdit != null) {
      _selectedSubject = widget.questionToEdit!.subject;
      _selectedTopic = widget.questionToEdit!.topic;
      _questionController.text = widget.questionToEdit!.text;
      _explanationController.text = widget.questionToEdit!.explanation;
      _isCorrect = widget.questionToEdit!.isCorrect;
    } else {
      _selectedSubject = _subjectTopics.keys.first;
      _selectedTopic = _subjectTopics[_selectedSubject]!.first;
    }
  }

  void _saveQuestion() async {
    if (_questionController.text.isEmpty || _explanationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('問題文と解説を入力してください')));
      return;
    }

    final questionData = Question(
      id: widget.questionToEdit?.id, 
      subject: _selectedSubject,
      topic: _selectedTopic,
      text: _questionController.text,
      isCorrect: _isCorrect,
      explanation: _explanationController.text,
    );

    if (widget.questionToEdit == null) {
      await DatabaseHelper.instance.insert(questionData); 
    } else {
      await DatabaseHelper.instance.update(questionData); 
    }
    
    widget.onSuccess();
    setState(() => _isSaved = true);

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _isSaved = false;
        if (widget.questionToEdit == null) {
          _questionController.clear();
          _explanationController.clear();
        }
      });
    }
  }

  void _deleteQuestion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本当に削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除する', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && widget.questionToEdit?.id != null) {
      await DatabaseHelper.instance.delete(widget.questionToEdit!.id!);
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.questionToEdit != null)
            Align(
              alignment: Alignment.topRight,
              child: OutlinedButton.icon(
                onPressed: _deleteQuestion, icon: const Icon(Icons.delete, color: Colors.red), label: const Text('この問題を削除', style: TextStyle(color: Colors.red)),
              ),
            ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            value: _selectedSubject,
            decoration: const InputDecoration(labelText: '科目', border: OutlineInputBorder()),
            items: _subjectTopics.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSubject = value!;
                _selectedTopic = _subjectTopics[_selectedSubject]!.first;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedTopic,
            decoration: const InputDecoration(labelText: '論点・範囲', border: OutlineInputBorder()),
            items: _subjectTopics[_selectedSubject]!.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (value) => setState(() => _selectedTopic = value!),
          ),
          const SizedBox(height: 16),
          
          TextField(controller: _questionController, minLines: 3, maxLines: 10, decoration: const InputDecoration(labelText: '問題文', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          
          Row(
            children: [
              const Text('正解は：', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 16),
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: true, label: Text('〇 (True)')), ButtonSegment(value: false, label: Text('✕ (False)'))],
                selected: {_isCorrect},
                onSelectionChanged: (Set<bool> newSelection) => setState(() => _isCorrect = newSelection.first),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(controller: _explanationController, minLines: 4, maxLines: 15, decoration: const InputDecoration(labelText: '解説', border: OutlineInputBorder())),
          const SizedBox(height: 32),

          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: _isSaved
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 80, key: ValueKey('saved_icon'))
                  : SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton.icon(
                        key: const ValueKey('save_button'),
                        onPressed: _saveQuestion, icon: const Icon(Icons.save), label: const Text('保存する', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primaryContainer),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final List<Question> questions;
  const QuizScreen({super.key, required this.questions});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int currentIndex = 0;

  void _answerQuestion(bool userAnswer) {
    final currentQuestion = widget.questions[currentIndex];
    final isCorrect = (userAnswer == currentQuestion.isCorrect);
    
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isCorrect ? '⭕ 正解！' : '❌ 不正解...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.red)),
                const SizedBox(height: 16),
                Flexible(child: SingleChildScrollView(child: Text('【解説】\n${currentQuestion.explanation}', style: const TextStyle(fontSize: 16, height: 1.6)))),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        if (currentIndex < widget.questions.length - 1) currentIndex++;
                        else Navigator.pop(context);
                      });
                    },
                    child: Text(currentIndex < widget.questions.length - 1 ? '次の問題へ' : '終了して戻る'),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[currentIndex];
    return Scaffold(
      appBar: AppBar(title: Text('${question.category} (${currentIndex + 1}/${widget.questions.length})')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Center(child: SingleChildScrollView(child: Text(question.text, style: const TextStyle(fontSize: 20, height: 1.6))))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(36), backgroundColor: Colors.blue[50]), onPressed: () => _answerQuestion(true), child: const Text('〇', style: TextStyle(fontSize: 48, color: Colors.blue))),
                ElevatedButton(style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(36), backgroundColor: Colors.red[50]), onPressed: () => _answerQuestion(false), child: const Text('✕', style: TextStyle(fontSize: 48, color: Colors.red))),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
