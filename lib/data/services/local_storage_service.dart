import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) throw StateError('LocalStorageService not initialized');
    return _prefs!;
  }

  bool getBool(String key, {bool defaultValue = false}) =>
      prefs.getBool(key) ?? defaultValue;

  void setBool(String key, bool value) => prefs.setBool(key, value);

  int getInt(String key, {int defaultValue = 0}) =>
      prefs.getInt(key) ?? defaultValue;

  void setInt(String key, int value) => prefs.setInt(key, value);

  String getString(String key, {String defaultValue = ''}) =>
      prefs.getString(key) ?? defaultValue;

  void setString(String key, String value) => prefs.setString(key, value);

  void setStringList(String key, List<String> value) =>
      prefs.setStringList(key, value);

  Set<String> getStringSet(String key) =>
      prefs.getStringList(key)?.toSet() ?? {};

  void addToStringSet(String key, String value) {
    final set = getStringSet(key);
    set.add(value);
    prefs.setStringList(key, set.toList());
  }

  void removeFromStringSet(String key, String value) {
    final set = getStringSet(key);
    set.remove(value);
    prefs.setStringList(key, set.toList());
  }

  Future<String> get documentsDir async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<File> saveFile(String fileName, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    return file.writeAsBytes(bytes);
  }

  Future<File?> getFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) return file;
    return null;
  }

  Future<bool> deleteFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}
