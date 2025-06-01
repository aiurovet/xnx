import 'dart:io';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/path.dart';

class Helper {
  static const defaultDelay = 10; // milliseconds

  static final List<MemoryFileSystem> memoryFileSystems = [
    MemoryFileSystem(style: FileSystemStyle.posix),
    MemoryFileSystem(style: FileSystemStyle.windows)
  ];

  static void forEachMemoryFileSystem(
      void Function(MemoryFileSystem fs) handler) {
    for (var fs in memoryFileSystems) {
      handler(fs);
    }
  }

  static String getFileSystemStyleName(FileSystem fs) =>
      (fs as StyleableFileSystem).style.toString();

  static void initFileSystem(FileSystem fs, {bool canShow = true}) {
    Env.init(fileSystem: fs);

    if (canShow) {
      print('FS: ${getFileSystemStyleName(Path.fileSystem)}');
    }
  }

  static void shortSleep([int delay = defaultDelay]) =>
      sleep(Duration(milliseconds: delay));
}
