import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Database Helper
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'todo.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        isCompleted INTEGER
      )
    ''');
  }

  Future<int> insertTodo(Map<String, dynamic> todo) async {
    Database db = await database;
    return await db.insert('todos', todo);
  }

  Future<List<Map<String, dynamic>>> getTodos() async {
    Database db = await database;
    return await db.query('todos');
  }

  Future<int> updateTodo(Map<String, dynamic> todo) async {
    Database db = await database;
    return await db.update(
      'todos',
      todo,
      where: 'id = ?',
      whereArgs: [todo['id']],
    );
  }

  Future<int> deleteTodo(int id) async {
    Database db = await database;
    return await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// Todo Model
class Todo {
  int? id;
  String title;
  String description;
  bool isCompleted;

  Todo({
    this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      isCompleted: map['isCompleted'] == 1,
    );
  }
}

// Todo List Screen
class TodoListScreen extends StatefulWidget {
  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<Todo> _todos = [];

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final List<Map<String, dynamic>> maps = await _databaseHelper.getTodos();
    setState(() {
      _todos = maps.map((map) => Todo.fromMap(map)).toList();
    });
  }

  Future<void> _deleteTodo(int id) async {
    await _databaseHelper.deleteTodo(id);
    _loadTodos();
  }

  Future<void> _toggleTodoCompletion(Todo todo) async {
    todo.isCompleted = !todo.isCompleted;
    await _databaseHelper.updateTodo(todo.toMap());
    _loadTodos();
  }

  void _navigateToAddTodo(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TodoFormScreen()),
    );

    if (result != null && result is bool && result) {
      _loadTodos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Todo List'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _navigateToAddTodo(context),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _todos.length,
        itemBuilder: (context, index) {
          final todo = _todos[index];
          return ListTile(
            title: Text(
              todo.title,
              style: TextStyle(
                decoration: todo.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            subtitle: Text(todo.description),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _deleteTodo(todo.id!),
            ),
            leading: Checkbox(
              value: todo.isCompleted,
              onChanged: (value) => _toggleTodoCompletion(todo),
            ),
          );
        },
      ),
    );
  }
}

// Todo Form Screen
class TodoFormScreen extends StatefulWidget {
  final Todo? todo;

  TodoFormScreen({this.todo});

  @override
  _TodoFormScreenState createState() => _TodoFormScreenState();
}

class _TodoFormScreenState extends State<TodoFormScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _description;

  @override
  void initState() {
    super.initState();
    _title = widget.todo?.title ?? '';
    _description = widget.todo?.description ?? '';
  }

  Future<void> _saveTodo(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (widget.todo == null) {
        await _databaseHelper.insertTodo(
          Todo(
            title: _title,
            description: _description,
          ).toMap(),
        );
      } else {
        await _databaseHelper.updateTodo(
          Todo(
            id: widget.todo!.id,
            title: _title,
            description: _description,
            isCompleted: widget.todo!.isCompleted,
          ).toMap(),
        );
      }

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.todo == null ? 'Add Todo' : 'Edit Todo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _title,
                decoration: InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                onSaved: (value) {
                  _title = value!;
                },
              ),
              TextFormField(
                initialValue: _description,
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
                onSaved: (value) {
                  _description = value!;
                },
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () => _saveTodo(context),
                child: Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Todo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TodoListScreen(),
    );
  }
}
