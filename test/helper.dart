import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/path.dart';

class Helper {
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
}
