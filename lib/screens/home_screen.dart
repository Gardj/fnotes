import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/tag_repository.dart';
import '../widgets/tags_editor_widget.dart';
import '../widgets/tags_dialog_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<Note> notesBox;
  late Box<NoteFolder> foldersBox;

  List<dynamic> _items = [];
  List<String> allTags = [];
  Note? _selectedNote;
  String _searchQuery = '';
  final List<String> _selectedTags = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String? editingFolderName;
  bool _isDarkMode = true;
  bool _isHiveReady = false;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(NoteFolderAdapter());

    notesBox = await Hive.openBox<Note>('notesBox');
    foldersBox = await Hive.openBox<NoteFolder>('foldersBox');

    await TagRepository().init();

    setState(() {
      _items = [...foldersBox.values.toList(), ...notesBox.values.toList()];
      allTags = List.from(TagRepository().tags);
      _isHiveReady = true;
    });
  }

  void _createNote() {
    if (!_isHiveReady) return;

    final newNote = Note(title: '');
    notesBox.add(newNote);
    setState(() {
      _items.add(newNote);
      _selectedNote = newNote;
      _titleController.text = newNote.title;
      _contentController.text = newNote.content;
    });
  }

  void _selectNote(Note note) {
    setState(() {
      _selectedNote = note;
      _titleController.text = note.title;
      _contentController.text = note.content;
    });
  }

  void _updateSelectedNote({String? newTitle, String? newContent}) {
    if (_selectedNote == null) return;
    setState(() {
      if (newTitle != null) _selectedNote!.title = newTitle;
      if (newContent != null) _selectedNote!.content = newContent;
      _selectedNote!.updatedAt = DateTime.now();
      _selectedNote!.save();
    });
  }

  void _showNoteInfoDialog(BuildContext context) {
    if (_selectedNote == null) return;
    final note = _selectedNote!;
    showDialog(
      context: context,
      builder: (context) => TagDialog(
        note: note,
        allTags: allTags,
        onTagsUpdated: (updatedTags) {
          setState(() {
            note.tags = updatedTags;
            note.save();
          });
        },
        formatDate: (date) =>
            '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.'
            '${date.year} '
            '${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')}',
      ),
    );
  }

  void _showTagFilterDialog() async {
    if (!_isHiveReady) return;

    List<String> selectedTagsCopy = List.from(_selectedTags);
    final result = await showDialog<List<String>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: _isDarkMode ? const Color(0xFF2B2B2B) : Colors.white,
        child: StatefulBuilder(
          builder: (context, setStateDialog) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: 350,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Выберите теги для фильтра',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.indigo[200] : Colors.indigo),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: allTags.length,
                      itemBuilder: (context, index) {
                        final tag = allTags[index];
                        final isSelected = selectedTagsCopy.contains(tag);
                        return InkWell(
                          onTap: () {
                            setStateDialog(() {
                              if (isSelected) {
                                selectedTagsCopy.remove(tag);
                              } else {
                                selectedTagsCopy.add(tag);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (_isDarkMode
                                      ? Colors.indigo[800]?.withOpacity(0.3)
                                      : Colors.indigo[100]?.withOpacity(0.3))
                                  : (_isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? (_isDarkMode
                                        ? Colors.indigo[400]!
                                        : Colors.indigo)
                                    : (_isDarkMode ? Colors.grey[700]! : Colors.grey),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (checked) {
                                    setStateDialog(() {
                                      if (checked == true) {
                                        selectedTagsCopy.add(tag);
                                      } else {
                                        selectedTagsCopy.remove(tag);
                                      }
                                    });
                                  },
                                  activeColor: Colors.indigo[400],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isSelected
                                        ? (_isDarkMode
                                            ? Colors.indigo[100]
                                            : Colors.indigo[900])
                                        : (_isDarkMode ? Colors.grey[300] : Colors.grey[800]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: Text('Отмена',
                            style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.indigo[200]
                                    : Colors.indigo))),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, selectedTagsCopy),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[400],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text('Применить'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedTags
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isHiveReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final folders = _items.whereType<NoteFolder>().toList();
    final notes = _items.whereType<Note>().toList();
    final filteredItems = [
      ...folders.where((folder) => folder.notes.any((note) {
            final matchesQuery =
                note.title.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesTags =
                _selectedTags.isEmpty || note.tags.any((t) => _selectedTags.contains(t));
            return matchesQuery && matchesTags;
          })),
      ...notes.where((note) {
        final matchesQuery =
            note.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesTags =
            _selectedTags.isEmpty || note.tags.any((t) => _selectedTags.contains(t));
        return matchesQuery && matchesTags;
      }),
    ];

    return MaterialApp(
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        cardColor: const Color(0xFF2B2B2B),
        primaryColor: Colors.indigo[400],
      ),
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.grey[200],
        cardColor: Colors.white,
        primaryColor: Colors.indigo,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: _isDarkMode ? const Color(0xFF2B2B2B) : Colors.indigo,
          title: const Text('Заметки', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.local_offer),
              tooltip: 'Теги',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => TagsEditor(
                    tags: allTags,
                    onTagsChanged: (updatedTags) {
                      setState(() {
                        TagRepository().setTags(updatedTags);
                        allTags = List.from(updatedTags);
                      });
                    },
                  ),
                );
              },
            ),
            Row(
              children: [
                const Icon(Icons.wb_sunny, color: Colors.white70),
                Switch(
                  value: _isDarkMode,
                  activeColor: Colors.indigo[400],
                  onChanged: (value) {
                    setState(() {
                      _isDarkMode = value;
                    });
                  },
                ),
                const Icon(Icons.nights_stay, color: Colors.white70),
              ],
            ),
          ],
        ),
        body: Row(
          children: [
            Container(
              width: 350,
              color: _isDarkMode ? const Color(0xFF2B2B2B) : Colors.grey[200],
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                                color: _isDarkMode ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Поиск...',
                              hintStyle: TextStyle(
                                  color:
                                      _isDarkMode ? Colors.grey[500] : Colors.grey[600]),
                              prefixIcon: Icon(Icons.search,
                                  color: _isDarkMode ? Colors.grey : Colors.black54),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear,
                                          color: _isDarkMode
                                              ? Colors.grey
                                              : Colors.black54),
                                      onPressed: () {
                                        setState(() {
                                          _searchQuery = '';
                                          _searchController.clear();
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.filter_list,
                              color: _isDarkMode ? Colors.indigoAccent : Colors.indigo),
                          tooltip: 'Фильтр по тегам',
                          onPressed: _showTagFilterDialog,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        ...filteredItems.map((item) {
                          if (item is NoteFolder) return _buildFolderTile(item);
                          if (item is Note) return _buildDraggableNote(item);
                          return const SizedBox.shrink();
                        }),
                        _buildDropArea(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      onPressed: _createNote,
                      icon: const Icon(Icons.add),
                      label: const Text("Создать"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[400],
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
                padding: const EdgeInsets.all(16),
                child: _selectedNote == null
                    ? Center(
                        child: Text(
                          "Выберите или создайте заметку",
                          style: TextStyle(
                              color: _isDarkMode ? Colors.grey : Colors.black54),
                        ),
                      )
                    : Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Заметка',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _isDarkMode ? Colors.white : Colors.black)),
                              IconButton(
                                icon: Icon(Icons.more_vert,
                                    color: _isDarkMode ? Colors.white : Colors.black),
                                onPressed: () => _showNoteInfoDialog(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleController,
                            style: TextStyle(
                                color: _isDarkMode ? Colors.white : Colors.black),
                            decoration:
                                const InputDecoration(labelText: "Заголовок"),
                            onChanged: (v) => _updateSelectedNote(newTitle: v),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TextField(
                              controller: _contentController,
                              style: TextStyle(
                                  color: _isDarkMode ? Colors.white : Colors.black),
                              decoration:
                                  const InputDecoration(labelText: "Описание"),
                              maxLines: null,
                              expands: true,
                              onChanged: (v) => _updateSelectedNote(newContent: v),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableNote(Note note) {
    return LongPressDraggable<Note>(
      data: note,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.indigo[400],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(note.title,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _noteCard(note)),
      child: DragTarget<Note>(
        onAccept: (draggedNote) async {
          if (draggedNote != note) {
            // Создаём новую папку
            final newFolder = NoteFolder(name: "Новая папка", notes: [note, draggedNote]);
            await foldersBox.add(newFolder);

            // Убираем заметки из UI
            setState(() {
              _items.remove(note);
              _items.remove(draggedNote);
              _items.add(newFolder);
            });
          }
        },
        builder: (context, candidate, rejected) => _noteCard(note),
      ),
    );
  }

  Widget _noteCard(Note note) {
    return Card(
      color: _isDarkMode ? const Color(0xFF2B2B2B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo[400]!, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(note.title,
            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        onTap: () => _selectNote(note),
      ),
    );
  }

  Widget _buildFolderTile(NoteFolder folder) {
    return DragTarget<Note>(
      onAccept: (draggedNote) async {
        if (!folder.notes.contains(draggedNote)) {
          folder.notes.add(draggedNote);
          await folder.save();
          setState(() {
            _items.remove(draggedNote);
          });
        }
      },
      builder: (context, candidate, rejected) => Card(
        color: _isDarkMode ? const Color(0xFF2B2B2B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ExpansionTile(
          title: editingFolderName == folder.name
              ? TextField(
                  autofocus: true,
                  controller: TextEditingController(text: folder.name),
                  style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                  onSubmitted: (value) async {
                    setState(() {
                      if (value.isNotEmpty) folder.name = value;
                      editingFolderName = null;
                    });
                    await folder.save();
                  },
                )
              : GestureDetector(
                  onLongPress: () {
                    setState(() {
                      editingFolderName = folder.name;
                    });
                  },
                  child: Text(folder.name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black))),
          children: folder.notes.map(_buildDraggableNote).toList(),
        ),
      ),
    );
  }

  Widget _buildDropArea() {
    return DragTarget<Note>(
      onAccept: (note) {
        setState(() {
          for (var item in _items) {
            if (item is NoteFolder && item.notes.contains(note)) {
              item.notes.remove(note);
              if (item.notes.length == 1) {
                final lastNote = item.notes.first;
                _items.remove(item);
                _items.add(lastNote);
              }
              break;
            }
          }
          if (!_items.contains(note)) _items.add(note);
        });
      },
      builder: (context, candidate, rejected) => Container(
        height: 50,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
              color: candidate.isNotEmpty
                  ? Colors.indigo[400]!
                  : (_isDarkMode ? Colors.grey[700]! : Colors.grey)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
            child: Text("Перетащи сюда, чтобы вынести",
                style: TextStyle(color: _isDarkMode ? Colors.grey : Colors.black54))),
      ),
    );
  }
}
