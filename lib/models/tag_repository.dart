import 'package:hive/hive.dart';

class TagRepository {
  static final TagRepository _instance = TagRepository._internal();
  late Box<String> _tagsBox;

  factory TagRepository() => _instance;

  TagRepository._internal();


  Future<void> init() async {
    _tagsBox = await Hive.openBox<String>('tagsBox');
  }

  List<String> get tags => _tagsBox.values.toList();

  void addTag(String tag) {
    if (!_tagsBox.values.contains(tag)) {
      _tagsBox.add(tag);
    }
  }

  void updateTag(String oldTag, String newTag) {
    final key = _tagsBox.keys.firstWhere(
        (k) => _tagsBox.get(k) == oldTag,
        orElse: () => null);
    if (key != null && !_tagsBox.values.contains(newTag)) {
      _tagsBox.put(key, newTag);
    }
  }

  void deleteTag(String tag) {
    final key = _tagsBox.keys.firstWhere(
        (k) => _tagsBox.get(k) == tag,
        orElse: () => null);
    if (key != null) {
      _tagsBox.delete(key);
    }
  }

  void setTags(List<String> newTags) {
    _tagsBox.clear();
    for (var tag in newTags.toSet()) {
      _tagsBox.add(tag);
    }
  }
}
