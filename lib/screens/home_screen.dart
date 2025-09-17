import 'package:flutter/foundation.dart';
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

  List<dynamic> _items = []; // folders first, then standalone notes
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

  // ----------------- HELPERS -----------------

  /// Надёжное сравнение заметок по createdAt + title (уникальность)
  bool _sameNote(Note a, Note b) {
    return a.createdAt.millisecondsSinceEpoch == b.createdAt.millisecondsSinceEpoch &&
        a.title == b.title;
  }

  /// Ищем авторитетный экземпляр заметки в notesBox (если есть)
  Note? _findNoteInBox(Note maybe) {
    for (var n in notesBox.values) {
      if (_sameNote(n, maybe)) return n;
    }
    return null;
  }

  /// Синхронизируем одной папке её заметки, заменяя сохранённые копии на экземпляры из notesBox (если найдены).
  /// Возвращает true если произошли изменения (и нужно сохранить папку).
  Future<bool> _syncFolderWithBox(NoteFolder folder) async {
    final List<Note> synced = [];
    bool changed = false;
    for (var stored in folder.notes) {
      final authoritative = _findNoteInBox(stored);
      if (authoritative != null) {
        synced.add(authoritative);
      } else {
        // заметка была удалена из notesBox — пропускаем её
        changed = true;
      }
    }

    // если список изменений (кол-во или ссылки)
    if (synced.length != folder.notes.length ||
        !listEquals(synced, folder.notes)) {
      folder.notes = synced;
      // Если папка стала пустой — удалим её, иначе сохраним
      if (folder.notes.isEmpty) {
        await folder.delete();
      } else {
        await folder.save();
      }
      return true;
    }
    return false;
  }

  /// Перестраиваем UI-список _items:
  /// 1) синхроним папки с notesBox (удаляем отсутствующие заметки из папок);
  /// 2) получаем только те заметки из notesBox, которые НЕ находятся в папках;
  /// 3) _items = [folders..., notesNotInFolders...]
  Future<void> _rebuildItems() async {
    final folders = foldersBox.values.toList();

    // Синхронизация папок с authoritative notesBox
    for (var folder in folders) {
      await _syncFolderWithBox(folder);
    }

    final updatedFolders = foldersBox.values.toList();

    // Отбираем заметки, которых нет в папках
    final notesNotInFolders = notesBox.values.where((n) {
      for (var f in updatedFolders) {
        for (var fn in f.notes) {
          if (_sameNote(fn, n)) return false;
        }
      }
      return true;
    }).toList();

    setState(() {
      _items = [...updatedFolders, ...notesNotInFolders];
    });
  }

  // ----------------- INIT / HIVE -----------------

  Future<void> _initHive() async {
    await Hive.initFlutter();
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(NoteFolderAdapter());

    notesBox = await Hive.openBox<Note>('notesBox');
    foldersBox = await Hive.openBox<NoteFolder>('foldersBox');

    await TagRepository().init();
    allTags = List.from(TagRepository().tags);

    await _rebuildItems();
    _isHiveReady = true;
    setState(() {});
  }

  // ----------------- NOTES / UI ACTIONS -----------------

  Future<void> _createNote() async {
    if (!_isHiveReady) return;
    final newNote = Note(title: '');
    await notesBox.add(newNote);
    await _rebuildItems();
    setState(() {
      _selectedNote = newNote;
      _titleController.text = newNote.title;
      _contentController.text = newNote.content;
    });
  }

  /// Устанавливаем выбор — берём authoritative экземпляр из notesBox, если он есть
  void _selectNote(Note note) {
    final authoritative = _findNoteInBox(note) ?? note;
    setState(() {
      _selectedNote = authoritative;
      _titleController.text = authoritative.title;
      _contentController.text = authoritative.content;
    });
  }

  Future<void> _updateSelectedNote({String? newTitle, String? newContent}) async {
    if (_selectedNote == null) return;
    if (newTitle != null) _selectedNote!.title = newTitle;
    if (newContent != null) _selectedNote!.content = newContent;
    _selectedNote!.updatedAt = DateTime.now();
    await _selectedNote!.save();
    await _rebuildItems(); // обновим левую панель
  }

  void _showNoteInfoDialog(BuildContext context) {
    if (_selectedNote == null) return;
    final authoritative = _findNoteInBox(_selectedNote!) ?? _selectedNote!;
    showDialog(
      context: context,
      builder: (context) => TagDialog(
        note: authoritative,
        allTags: allTags,
        onTagsUpdated: (updatedTags) async {
          authoritative.tags = updatedTags;
          await authoritative.save();
          await _rebuildItems();
          setState(() {});
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

  Future<void> _showTagFilterDialog() async {
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
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (_isDarkMode ? Colors.indigo[800]?.withOpacity(0.3) : Colors.indigo[100]?.withOpacity(0.3))
                                  : (_isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? (_isDarkMode ? Colors.indigo[400]! : Colors.indigo)
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
                                        ? (_isDarkMode ? Colors.indigo[100] : Colors.indigo[900])
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
                    TextButton(onPressed: () => Navigator.pop(context, null), child: Text('Отмена', style: TextStyle(color: _isDarkMode ? Colors.indigo[200] : Colors.indigo))),
                    const SizedBox(width: 12),
                    ElevatedButton(onPressed: () => Navigator.pop(context, selectedTagsCopy), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[400], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Применить')),
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
      await _rebuildItems();
    }
  }

  Future<void> _deleteNote(Note note) async {
    // удалить из папок
    final folders = foldersBox.values.toList();
    for (var folder in folders) {
      final before = folder.notes.length;
      folder.notes.removeWhere((fn) => _sameNote(fn, note));
      if (folder.notes.length != before) {
        if (folder.notes.isEmpty) {
          await folder.delete();
        } else {
          await folder.save();
        }
      }
    }

    // удалить из notesBox
    dynamic foundKey;
    for (var entry in notesBox.toMap().entries) {
      final v = entry.value as Note;
      if (_sameNote(v, note)) {
        foundKey = entry.key;
        break;
      }
    }
    if (foundKey != null) {
      await notesBox.delete(foundKey);
    }

    if (_selectedNote != null && _sameNote(_selectedNote!, note)) {
      _selectedNote = null;
      _titleController.clear();
      _contentController.clear();
    }

    await _rebuildItems();
  }

  void _deleteNoteConfirmation(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтвердите удаление'),
        content: const Text('Удалить заметку? Это действие необратимо.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteNote(note);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ----------------- BUILD / WIDGETS -----------------

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Фильтрация / порядок: сначала папки, затем заметки
    final folders = _items.whereType<NoteFolder>().toList();
    final notes = _items.whereType<Note>().toList();
    final filteredItems = [
      ...folders.where((folder) => folder.notes.any((note) {
            final matchesQuery = note.title.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesTags = _selectedTags.isEmpty || note.tags.any((t) => _selectedTags.contains(t));
            return matchesQuery && matchesTags;
          })),
      ...notes.where((note) {
        final matchesQuery = note.title.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesTags = _selectedTags.isEmpty || note.tags.any((t) => _selectedTags.contains(t));
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
                    onTagsChanged: (updatedTags) async {
                      TagRepository().setTags(updatedTags);
                      setState(() {
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
            // Левая панель
            Container(
              width: 350,
              color: _isDarkMode ? const Color(0xFF2B2B2B) : Colors.grey[200],
              child: Column(
                children: [
                  // Поиск + фильтр
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Поиск...',
                              hintStyle: TextStyle(color: _isDarkMode ? Colors.grey[500] : Colors.grey[600]),
                              prefixIcon: Icon(Icons.search, color: _isDarkMode ? Colors.grey : Colors.black54),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: _isDarkMode ? Colors.grey : Colors.black54),
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
                          icon: Icon(Icons.filter_list, color: _isDarkMode ? Colors.indigoAccent : Colors.indigo),
                          tooltip: 'Фильтр по тегам',
                          onPressed: _showTagFilterDialog,
                        ),
                      ],
                    ),
                  ),

                  // Список
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

                  // Создать заметку
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      onPressed: () async => await _createNote(),
                      icon: const Icon(Icons.add),
                      label: const Text("Создать"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[400],
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Правая панель для редактирования
            Expanded(
              child: Container(
                color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
                padding: const EdgeInsets.all(16),
                child: _selectedNote == null
                    ? Center(child: Text("Выберите или создайте заметку", style: TextStyle(color: _isDarkMode ? Colors.grey : Colors.black54)))
                    : Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Заметка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black)),
                              IconButton(icon: Icon(Icons.more_vert, color: _isDarkMode ? Colors.white : Colors.black), onPressed: () => _showNoteInfoDialog(context)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _titleController,
                            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                            decoration: const InputDecoration(labelText: "Заголовок"),
                            onChanged: (v) => _updateSelectedNote(newTitle: v),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TextField(
                              controller: _contentController,
                              style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                              decoration: const InputDecoration(labelText: "Описание"),
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

  // ----------------- DRAG & DROP / WIDGETS -----------------

  Widget _buildDraggableNote(Note note) {
    // note здесь берётся из _items (вызов _rebuildItems гарантирует, что note — authoritative)
    return LongPressDraggable<Note>(
      data: note,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.indigo[400], borderRadius: BorderRadius.circular(12)),
          child: Text(note.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _noteCard(note)),
      child: DragTarget<Note>(
        onWillAccept: (incoming) => incoming != null && !_sameNote(incoming, note),
        onAccept: (draggedNote) async {
          if (_sameNote(draggedNote, note)) return;

          // Очистим любое вхождение этих заметок в других папках
          final folders = foldersBox.values.toList();
          for (var folder in folders) {
            final before = folder.notes.length;
            folder.notes.removeWhere((fn) => _sameNote(fn, note) || _sameNote(fn, draggedNote));
            if (folder.notes.length != before) {
              if (folder.notes.isEmpty) {
                await folder.delete();
              } else {
                await folder.save();
              }
            }
          }

          // Создаем новую папку (используем authoritative экземпляры, если есть)
          final a = _findNoteInBox(note) ?? note;
          final b = _findNoteInBox(draggedNote) ?? draggedNote;
          final newFolder = NoteFolder(name: "Новая папка", notes: [a, b]);
          await foldersBox.add(newFolder);

          await _rebuildItems();
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
        title: Text(note.title, style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
        onTap: () => _selectNote(note),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: _isDarkMode ? Colors.red[300] : Colors.red),
          tooltip: 'Удалить заметку',
          onPressed: () => _deleteNoteConfirmation(note),
        ),
      ),
    );
  }

  Widget _buildFolderTile(NoteFolder folder) {
    return DragTarget<Note>(
      onWillAccept: (incoming) => incoming != null && !folder.notes.any((fn) => _sameNote(fn, incoming)),
      onAccept: (draggedNote) async {
        // удалить draggedNote из других папок
        final folders = foldersBox.values.toList();
        for (var f in folders) {
          if (f.key == folder.key) continue;
          final before = f.notes.length;
          f.notes.removeWhere((fn) => _sameNote(fn, draggedNote));
          if (f.notes.length != before) {
            if (f.notes.isEmpty) {
              await f.delete();
            } else {
              await f.save();
            }
          }
        }

        // добавляем authoritative (если найден) и сохраняем текущую папку
        final canonical = _findNoteInBox(draggedNote) ?? draggedNote;
        folder.notes.add(canonical);
        await folder.save();

        await _rebuildItems();
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
                    if (value.isNotEmpty) folder.name = value;
                    editingFolderName = null;
                    await folder.save();
                    await _rebuildItems();
                  },
                )
              : GestureDetector(
                  onLongPress: () {
                    setState(() {
                      editingFolderName = folder.name;
                    });
                  },
                  child: Text(folder.name, style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black))),
          children: [
            // Для каждой заметки внутри папки показываем authoritative экземпляр (если он есть)
            ...folder.notes.map((stored) {
              final authoritative = _findNoteInBox(stored) ?? stored;
              return _buildDraggableNote(authoritative);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropArea() {
    return DragTarget<Note>(
      onWillAccept: (incoming) => incoming != null,
      onAccept: (note) async {
        // Вынос заметки из папки в корень: удаляем её из папки(ок)
        final folders = foldersBox.values.toList();
        for (var folder in folders) {
          final before = folder.notes.length;
          folder.notes.removeWhere((fn) => _sameNote(fn, note));
          if (folder.notes.length != before) {
            if (folder.notes.isEmpty) {
              await folder.delete();
            } else if (folder.notes.length == 1) {
              // если в папке осталась 1 заметка — оставляем её как обычную (удаляем папку)
              final last = folder.notes.first;
              await folder.delete();
              // last останется в notesBox — rebuild покажет его
            } else {
              await folder.save();
            }
            break;
          }
        }

        await _rebuildItems();
      },
      builder: (context, candidate, rejected) => Container(
        height: 50,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: candidate.isNotEmpty ? Colors.indigo[400]! : (_isDarkMode ? Colors.grey[700]! : Colors.grey)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text("Перетащи сюда, чтобы вынести", style: TextStyle(color: _isDarkMode ? Colors.grey : Colors.black54))),
      ),
    );
  }
}
