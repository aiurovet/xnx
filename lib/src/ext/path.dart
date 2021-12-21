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
  static RegExp rexSeparator = RegExp(r'[\/\\]');

  //////////////////////////////////////////////////////////////////////////////

  static String adjust(String? path) {
    if ((path == null) || path.isEmpty) {
      return '';
    }

    return path.trim().replaceAll(isWindowsFS ? r'/' : r'\', separator);
  }

  //////////////////////////////////////////////////////////////////////////////

  static String basename(String path) => fileSystem.path.basename(path);

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
  static set currentDirectory(Directory value) => fileSystem.currentDirectory = value;

  //////////////////////////////////////////////////////////////////////////////

  static String dirname(String path) => fileSystem.path.dirname(path);

  //////////////////////////////////////////////////////////////////////////////

  static bool equals(String path1, String path2) =>
      fileSystem.path.equals(path1, path2);

  //////////////////////////////////////////////////////////////////////////////

  static String extension(String path) => fileSystem.path.extension(path);

  //////////////////////////////////////////////////////////////////////////////

  static String getFullPath(String? path) {
      var full = fileSystem.path.canonicalize(Path.adjust(path));

      if (!Path.isWindowsFS || (path == null) || path.isEmpty) {
        return full;
      }

      // Due to path canonicalization on Windows converts the original path to lower case,
      // trying to keep the original parts of path as much as possible (at least, the basename)

      var partsOfFull = full.split(Path.separator);
      var partsOfPath = path.split(Path.separator);

      var cntFull = partsOfFull.length - 1;
      var cntPath = partsOfPath.length - 1;

      var isChanged = false;

      for (var curFull = cntFull, curPath = cntPath; (curFull >= 0) && (curPath >= 0); curFull--, curPath--) {
        var partOfFull = partsOfFull[curFull];
        var partOfPath = partsOfPath[curPath];

        if (partOfFull.length != partOfPath.length) {
          break;
        }

        if (partOfFull.toLowerCase() != partOfPath.toLowerCase()) {
          break;
        }

        isChanged = true;
        partsOfFull[curFull] = partOfPath;
      }

      return (isChanged ? partsOfFull.join(Path.separator) : full);
  }

  //////////////////////////////////////////////////////////////////////////////

  static void init(FileSystem? newFileSystem) {
    fileSystem = newFileSystem ?? localFileSystem;
    separator = fileSystem.path.separator;

    isWindowsFS = (separator == r'\');
    isCaseSensitive = !Path.equals('A', 'a');

    driveSeparator = (isWindowsFS ? ':' : '');
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isAbsolute(String path) => fileSystem.path.isAbsolute(path);

  //////////////////////////////////////////////////////////////////////////////

  static String join(String part1, [String? part2, String? part3, String? part4,
                     String? part5, String? part6, String? part7, String? part8]) =>
    fileSystem.path.join(part1, part2, part3, part4, part5, part6, part7, part8);

  //////////////////////////////////////////////////////////////////////////////

  static String joinAll(Iterable<String> parts) =>
      fileSystem.path.joinAll(parts);

  //////////////////////////////////////////////////////////////////////////////

  static String relative(String path, {String? from}) =>
      fileSystem.path.relative(path, from: from);

  //////////////////////////////////////////////////////////////////////////////

  static String replaceAll(String input, String fromPath, String toPath) {
    var rexFromPath = RegExp(RegExp.escape(fromPath.replaceAll(rexSeparator, '\x01'))
    .replaceAll('\x01', Path.rexSeparator.pattern), caseSensitive: !Path.isWindowsFS);

    return input.replaceAll(rexFromPath, toPath);
  }

  //////////////////////////////////////////////////////////////////////////////

  static String rootPrefix(String path) => fileSystem.path.rootPrefix(path);

  //////////////////////////////////////////////////////////////////////////////

  static List<List<String>> argsToLists(List<String> paths, {String? oper, bool isFirstSeparate = false, bool isLastSeparate = false}) {
    var pathCount = paths.length;
    var hasOper = ((pathCount <= 1) && !(oper?.isBlank() ?? true));

    if (pathCount <= 0) {
      if (hasOper) {
        throw Exception('No argument to $oper');
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
