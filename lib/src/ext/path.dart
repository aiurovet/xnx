import 'package:file/file.dart';
import 'package:file/local.dart';
import 'string.dart';

class Path {
  //////////////////////////////////////////////////////////////////////////////
  // Dependency injection
  //////////////////////////////////////////////////////////////////////////////

  static FileSystem fileSystem = localFileSystem;
  static FileSystem localFileSystem = LocalFileSystem();

  //////////////////////////////////////////////////////////////////////////////

  static String separator = '';
  static String driveSeparator = '';
  static bool isCaseSensitive = false;
  static bool isWindowsFS = false;

  //////////////////////////////////////////////////////////////////////////////

  static String basename(String path) => fileSystem.path.basename(path);

  //////////////////////////////////////////////////////////////////////////////

  static String adjust(String? path) {
    if ((path == null) || path.isEmpty) {
      return '';
    }

    return path.trim().replaceAll(isWindowsFS ? r'/' : r'\', separator);
  }

  //////////////////////////////////////////////////////////////////////////////

  static String argsToListAndDestination(
    List<String> retPaths, {
    String? path,
    List<String>? paths,
    String? destinationPath,
    bool hasDestination = false,
  }) {
    var retPath = '';
    retPaths.clear();

    if ((path != null) && path.isNotEmpty) {
      retPaths.add(path);
    }
    if ((paths != null) && paths.isNotEmpty) {
      retPaths.addAll(paths);
    }
    if ((destinationPath != null) && destinationPath.isNotEmpty) {
      hasDestination = true;
      retPaths.add(destinationPath);
    }
    if (retPaths.isEmpty) {
      return retPath;
    }
    if (hasDestination) {
      var last = (retPaths.length - 1);
      retPath = retPaths[last];
      retPaths.removeAt(last);
    }

    return retPath;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String basenameWithoutExtension(String path) =>
      fileSystem.path.basenameWithoutExtension(path);

  //////////////////////////////////////////////////////////////////////////////

  static Directory get currentDirectory => fileSystem.currentDirectory;

  //////////////////////////////////////////////////////////////////////////////

  static String dirname(String path) => fileSystem.path.dirname(path);

  //////////////////////////////////////////////////////////////////////////////

  static bool equals(String path1, String path2) =>
      fileSystem.path.equals(path1, path2);

  //////////////////////////////////////////////////////////////////////////////

  static String extension(String path) => fileSystem.path.extension(path);

  //////////////////////////////////////////////////////////////////////////////

  static String getFullPath(String? path) =>
      fileSystem.path.canonicalize(Path.adjust(path));

  //////////////////////////////////////////////////////////////////////////////

  static void init(FileSystem newFileSystem) {
    fileSystem = newFileSystem;
    separator = fileSystem.path.separator;

    isWindowsFS = (separator == r'\');
    isCaseSensitive = !Path.equals('A', 'a');

    driveSeparator = (isWindowsFS ? ':' : '');
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isAbsolute(String path) => fileSystem.path.isAbsolute(path);

  //////////////////////////////////////////////////////////////////////////////

  static String join(String part1,
          [String? part2,
          String? part3,
          String? part4,
          String? part5,
          String? part6,
          String? part7,
          String? part8]) =>
      fileSystem.path
          .join(part1, part2, part3, part4, part5, part6, part7, part8);

  //////////////////////////////////////////////////////////////////////////////

  static String joinAll(Iterable<String> parts) =>
      fileSystem.path.joinAll(parts);

  //////////////////////////////////////////////////////////////////////////////

  static String relative(String path, {String? from}) =>
      fileSystem.path.relative(path, from: from);

  //////////////////////////////////////////////////////////////////////////////

  static String rootPrefix(String path) => fileSystem.path.rootPrefix(path);

  //////////////////////////////////////////////////////////////////////////////

  static List<List<String>> argsToLists(List<String> paths, {String? oper, bool isFirstSeparate = false, bool isLastSeparate = false}) {
    var pathCount = paths.length;
    var hasOper = ((pathCount <= 1) && !(oper?.isBlank() ?? true));

    if (pathCount <= 0) {
      if (hasOper) {
        throw Exception('Nothing to $oper');
      }
      else {
        return [];
      }
    }

    if ((pathCount <= 1) && (isFirstSeparate || isLastSeparate)) {
      if (hasOper) {
        throw Exception('Unable to $oper "${paths[0]}": destination is not specifed');
      }
      else {
        return [];
      }
    }

    if (isFirstSeparate) {
      return [[paths[0]], paths.sublist(1, pathCount)];
    }

    if (isLastSeparate) {
      var last = pathCount - 1;
      return [paths.sublist(0, last), [paths[last]]];
    }

    return [paths];
  }

  //////////////////////////////////////////////////////////////////////////////

  static String toPosix(String path) => path.replaceAll('\\', '/');

  //////////////////////////////////////////////////////////////////////////////

}
