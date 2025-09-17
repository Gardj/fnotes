import 'package:hive/hive.dart';
import 'note.dart';

part 'note_folder.g.dart';

@HiveType(typeId: 1)
class NoteFolder extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<Note> notes;

  NoteFolder({required this.name, required this.notes});
}
