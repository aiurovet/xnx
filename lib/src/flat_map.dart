import 'package:meta/meta.dart';

class FlatMap {

  /////////////////////////////////////////////////////////////////////////////
  // Internals
  /////////////////////////////////////////////////////////////////////////////

  @protected final Map<String, String> map = {};

  /////////////////////////////////////////////////////////////////////////////
  // Interface
  /////////////////////////////////////////////////////////////////////////////

  Iterable<MapEntry<String, String>> get entries => map.entries;
  bool get isEmpty => map.isEmpty;
  bool get isNotEmpty => map.isNotEmpty;

  void add(FlatMap other) => map.addAll(other.map);
  void addAll(Map<String, String> other) => map.addAll(other);
  bool containsKey(String key) => map.containsKey(key);
  void forEach(void Function(String key, String value) action) => map.forEach(action);
  void remove(String key) => map.remove(key);

  /////////////////////////////////////////////////////////////////////////////
  // Getter
  /////////////////////////////////////////////////////////////////////////////

  String? operator [](String? key) => map[key];

  /////////////////////////////////////////////////////////////////////////////
  // Setter
  /////////////////////////////////////////////////////////////////////////////

  void operator []=(String? key, String? value) {
    if (key == null) {
      return;
    }

    if (value == null) {
      map.remove(key);
    }
    else {
      map[key] = value;
    }
  }

  /////////////////////////////////////////////////////////////////////////////

  String expand(String? value) {
    if (value == null) {
      return '';
    }

    if (value.isEmpty || map.isEmpty) {
      return value;
    }

    var safeValue = value;

    for (var oldValue = ''; oldValue != safeValue;) {
      oldValue = safeValue;

      map.forEach((k, v) {
        if (safeValue.contains(k)) {
          safeValue = safeValue.replaceAll(k, v.toString());
        }
      });
    }

    return safeValue;
  }

  /////////////////////////////////////////////////////////////////////////////

}