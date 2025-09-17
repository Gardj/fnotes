import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String content;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  List<String> tags;

  Note({required this.title})
      : content = '',
        createdAt = DateTime.now(),
        updatedAt = DateTime.now(),
        tags = [];
}
