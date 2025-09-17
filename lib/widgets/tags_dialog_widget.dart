import 'package:flutter/material.dart';
import '../models/note.dart';

class TagDialog extends StatelessWidget {
  final Note note;
  final List<String> allTags;
  final Function(List<String>) onTagsUpdated;
  final String Function(DateTime) formatDate;

  const TagDialog({
    super.key,
    required this.note,
    required this.allTags,
    required this.onTagsUpdated,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final unusedTags = allTags.where((tag) => !note.tags.contains(tag)).toList();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF2B2B2B) : Colors.white,
      title: const Text(
        'Информация о заметке',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Создана: ${formatDate(note.createdAt)}',
              style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
            ),
            Text(
              'Изменена: ${formatDate(note.updatedAt)}',
              style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 12),
            const Text('Теги:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: note.tags.isEmpty
                  ? [
                      Text(
                        'Нет тегов',
                        style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                      )
                    ]
                  : note.tags
                      .map((tag) => Chip(
                            backgroundColor:
                                isDarkMode ? Colors.indigo[800]?.withOpacity(0.3) : Colors.indigo[100],
                            label: Text(
                              tag,
                              style: TextStyle(
                                color: isDarkMode ? Colors.indigo[200] : Colors.indigo[800],
                              ),
                            ),
                            onDeleted: () {
                              final updated = List<String>.from(note.tags)..remove(tag);
                              onTagsUpdated(updated);
                              Navigator.of(context).pop();
                            },
                          ))
                      .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Добавить тег:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: unusedTags
                  .map((tag) => ActionChip(
                        backgroundColor: isDarkMode ? Colors.indigo[700] : Colors.indigo[100],
                        label: Text(
                          tag,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                        ),
                        onPressed: () {
                          final updated = List<String>.from(note.tags)..add(tag);
                          onTagsUpdated(updated);
                          Navigator.of(context).pop();
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            'Закрыть',
            style: TextStyle(color: isDarkMode ? Colors.indigo[200] : Colors.indigo[800]),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
