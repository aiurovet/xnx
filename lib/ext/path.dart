import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:xnx/ext/directory.dart';
import 'string.dart';

class Path {

  //////////////////////////////////////////////////////////////////////////////
  // Dependency injection
  //////////////////////////////////////////////////////////////////////////////

  static FileSystem fileSystem = localFileSystem;
  static FileSystem localFileSystem = LocalFileSystem();

  //////////////////////////////////////////////////////////////////////////////

  static String separator = '';
  static String separatorPosix = '/';
  static String separatorWindows = r'\';
  static String driveSeparator = '';
  static bool isCaseSensitive = false;
  static bool isWindowsFS = false;
  static RegExp rexSeparator = RegExp(r'[\/\\]');

  //////////////////////////////////////////////////////////////////////////////

  static String adjust(String? path) {
    if ((path == null) || path.isEmpty) {
      return '';
    }

    return path
      .trim()
      .replaceAll(isWindowsFS ? separatorPosix : separatorWindows, separator);
  }

  //////////////////////////////////////////////////////////////////////////////

  static String basename(String path) => fileSystem.path.basename(path);

  //////////////////////////////////////////////////////////////////////////////

  static bool contains(String source, String what) {
    if (isWindowsFS) {
      return source.toLowerCase().contains(what.toLowerCase());
    }
    return source.contains(what);
  }

  //////////////////////////////////////////////////////////////////////////////

  static String appendCurDirIfPathIsRelative(String prefix, String? path) {
    var pathEx = (path ?? '');
    var result = '$prefix"$pathEx"';

    if (pathEx.isEmpty || !isAbsolute(pathEx)) {
      result += ' (current dir: "${fileSystem.currentDirectory.path}")';
    }

    return result;
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
  static set currentDirectory(Directory value) => fileSystem.currentDirectory = value;

  static String get currentDirectoryName => fileSystem.currentDirectory.path;
  static set currentDirectoryName(String value) => fileSystem.currentDirectory = value;

  //////////////////////////////////////////////////////////////////////////////

  static String dirname(String path) => fileSystem.path.dirname(path);

  //////////////////////////////////////////////////////////////////////////////

  static bool equals(String path1, String path2) =>
      fileSystem.path.equals(path1, path2);

  //////////////////////////////////////////////////////////////////////////////

  static String extension(String path) => fileSystem.path.extension(path);

  /// Taken from my package `file_ext`
  ///
  /// Convert [aPath] to the fully qualified path\
  /// \
  /// For POSIX, it calls `canonicalize()`\
  /// For Windows, it takes an absolute path,
  /// prepends it with the current drive (if omitted),
  /// and resolves . and ..
  ///
  static String getFullPath(String? aPath) {
    // If path is null, return the current directory
    //
    if (aPath == null) {
      return fileSystem.currentDirectory.path;
    }

    // If path is empty, return the current directory
    //
    if (aPath.isEmpty) {
      return fileSystem.currentDirectory.path;
    }

    // Posix is always 'in chocolate'
    //
    if (!isWindowsFS) {
      return fileSystem.path.canonicalize(aPath);
    }

    aPath = adjust(aPath);

    // Get absolute path
    //
    var absPath = aPath;

    // If no drive is present, then take it from the current directory
    //
    if (aPath.startsWith(separator)) {
      final curDirName = fileSystem.currentDirectory.path;
      absPath = curDirName.substring(0, curDirName.indexOf(separator)) + aPath;
    } else if (!aPath.contains(driveSeparator)) {
      absPath = join(fileSystem.currentDirectory.path, aPath);
    }

    // Split path in parts (drive, directories, basename)
    //
    final parts = absPath.split(separator);
    var drive = parts[0];

    // Resolve all . and .. occurrences
    //
    var result = '';

    for (var i = 0, n = parts.length; i < n; i++) {
      final part = parts[i];

      switch (part) {
        case '':
          continue;
        case DirectoryExt.curDirAbbr:
          continue;
        case DirectoryExt.parentDirAbbr:
          final breakPos = result.lastIndexOf(separator);
          if (breakPos >= 0) {
            result = result.substring(0, breakPos);
          }
          continue;
        default:
          if (i > 0) {
            // full path should start with drive
            result += separator;
          }
          result += part;
          continue;
      }
    }

    // Disaster recovery
    //
    if (result.isEmpty) {
      result = drive + separator;
    } else if (result == drive) {
      result += separator;
    }

    // Return the result
    //
    return result;
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
    var pattern = "(^|[\\s\"']|\\:[\\/\\\\]+)";

    pattern += RegExp.escape(fromPath.replaceAll(rexSeparator, '\x01'))
      .replaceAll('\x01', Path.rexSeparator.pattern);

    pattern += "([\\s\"']|\$)";

    var rexFromPath = RegExp(pattern, caseSensitive: !Path.isWindowsFS);

    return input.replaceAllMapped(rexFromPath, (m) {
      return (m.group(1) ?? '') + toPath + (m.group(2) ?? '');
    });
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
