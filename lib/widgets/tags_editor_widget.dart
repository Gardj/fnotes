import 'package:flutter/material.dart';

class TagsEditor extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onTagsChanged;

  const TagsEditor({
    super.key,
    required this.tags,
    required this.onTagsChanged,
  });

  @override
  State<TagsEditor> createState() => _TagsEditorState();
}

class _TagsEditorState extends State<TagsEditor> {
  late List<String> _tags;
  final TextEditingController _controller = TextEditingController();
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.tags);
  }

  void _addTag() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _controller.clear();
      });
    }
  }

  void _updateTag() {
    final newText = _controller.text.trim();
    if (_selectedTag != null &&
        newText.isNotEmpty &&
        newText != _selectedTag &&
        !_tags.contains(newText)) {
      setState(() {
        final index = _tags.indexOf(_selectedTag!);
        _tags[index] = newText;
        _selectedTag = null;
        _controller.clear();
      });
    }
  }

  void _deleteTag() {
    if (_selectedTag != null) {
      setState(() {
        _tags.remove(_selectedTag);
        _selectedTag = null;
        _controller.clear();
      });
    }
  }

  void _onTagTap(String tag) {
    setState(() {
      _selectedTag = tag;
      _controller.text = tag;
    });
  }

  void _onClose() {
    widget.onTagsChanged(_tags);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDarkMode ? const Color(0xFF2B2B2B) : Colors.white,
      child: SizedBox(
        width: size.width * 0.8,
        height: size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              backgroundColor: isDarkMode ? const Color(0xFF2B2B2B) : Colors.indigo,
              title: const Text('Редактор тегов'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Закрыть',
                  onPressed: _onClose,
                )
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Список тегов слева
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: isDarkMode ? Colors.grey[700]! : Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.builder(
                            itemCount: _tags.length,
                            itemBuilder: (context, index) {
                              final tag = _tags[index];
                              final isSelected = _selectedTag == tag;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 8),
                                child: GestureDetector(
                                  onTap: () => _onTagTap(tag),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDarkMode
                                              ? Colors.indigo[800]?.withOpacity(0.3)
                                              : Colors.indigo[100])
                                          : (isDarkMode
                                              ? const Color(0xFF2B2B2B)
                                              : Colors.white),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.indigo[400]!
                                            : (isDarkMode
                                                ? Colors.grey[700]!
                                                : Colors.grey.shade400),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: isSelected
                                            ? Colors.indigo[400]
                                            : (isDarkMode ? Colors.white : Colors.black87),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Поле ввода и кнопки справа
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          TextField(
                            controller: _controller,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Название тега',
                              filled: true,
                              fillColor:
                                  isDarkMode ? const Color(0xFF2B2B2B) : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _selectedTag == null
                                    ? ElevatedButton(
                                        onPressed: _addTag,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo[400],
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('Добавить'),
                                      )
                                    : ElevatedButton(
                                        onPressed: _updateTag,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo[400],
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('Изменить'),
                                      ),
                              ),
                              if (_selectedTag != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _deleteTag,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[400],
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Удалить'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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
}
