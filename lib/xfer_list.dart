import 'dart:io';
import 'package:path/path.dart' as Path;
import 'ext/glob.dart';
import 'ext/string.dart';

class XferList {

  //////////////////////////////////////////////////////////////////////////////
  // Properties
  //////////////////////////////////////////////////////////////////////////////

  final List<String> _fromPaths = <String>[];
  List<String> get fromPaths => _fromPaths;

  FileSystemEntity _toEntity;
  FileSystemEntity get toEntity => _toEntity;

  bool _toEntityExists;
  bool get toEntityExists => _toEntityExists;

  //////////////////////////////////////////////////////////////////////////////

  XferList({String path, List<String> paths, int start, int end, bool isManyToOne, bool isOneToMany}) {
    if ((path != null) || (paths != null)) {
      init(
        fromPath: path, fromPaths: paths, start: start, end: end,
        isManyToOne: isManyToOne, isOneToMany: isOneToMany
      );
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  XferList init({String fromPath, List<String> fromPaths, String toPath, int start, int end, bool isManyToOne, bool isOneToMany}) {
    clear();

    if (fromPath != null) {
      add(fromPath);
    }

    if (fromPaths != null) {
      addRange(fromPaths, start: start, end: end);
    }

    if ((isManyToOne != null) || (isOneToMany != null) || (toPath != null)) {
      setDestination(isManyToOne: isManyToOne, isOneToMany: isOneToMany, toPath: toPath);
    }

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  XferList add(String fromPath) {
    if (!StringExt.isNullOrBlank(fromPath)) {
      _fromPaths.add(fromPath);
    }

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  XferList addRange(List<String> fromPaths, {int start, int end}) {
    final maxEnd = ((fromPaths?.length ?? 0) - 1);
    final startEx = ((start == null) || (start < 0) ? 0 : start);
    final endEx = ((end == null) || (end < 0) ? maxEnd : end);

    if ((startEx < endEx) && (endEx >= 0)) {
      if ((startEx == 0) && (endEx == maxEnd)) {
        fromPaths.addAll(fromPaths);
      }
      else {
        fromPaths.addAll(fromPaths.sublist(start, end));
      }
    }

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

  XferList clear() {
    _fromPaths.clear();
    _toEntity = null;
    _toEntityExists = false;
  }

  //////////////////////////////////////////////////////////////////////////////

  XferList setDestination({String toPath, bool isManyToOne, bool isOneToMany}) {
    _toEntity = null;
    _toEntityExists = false;

    String toPathEx;

    if (toPath == null) {
      final end = (_fromPaths.length - 1);

      if (end <= 0) {
        return this;
      }

      final isManyToOneEx = (isManyToOne ?? false);
      final isOneToManyEx = (isOneToMany ?? false);

      if (isManyToOneEx == isOneToMany) {
        return this;
      }

      toPathEx = _fromPaths[(isOneToManyEx ? 0 : end)];
    }
    else {
      toPathEx = toPath;
    }

    if (StringExt.isNullOrBlank(toPathEx) || GlobExt.isGlobPattern(toPathEx)) {
      return this;
    }

    final toDir = Directory(toPathEx);

    if (toDir.existsSync()) {
      _toEntity = toDir;
      _toEntityExists = true;
    }
    else {
      final toFile = File(toPathEx);

      if (toFile.existsSync()) {
        _toEntity = toFile;
        _toEntityExists = true;
      }
      else if (toPathEx.endsWith(StringExt.PATH_SEP)) {
        _toEntity = toDir;
      }
      else {
        _toEntity = toFile;
      }
    }

    if (_toEntity != null) {
      if (toPathEx != null) {
        _fromPaths.removeWhere((fromPath) => Path.equals(fromPath, toPath));
      }
    }

    return this;
  }

  //////////////////////////////////////////////////////////////////////////////

}