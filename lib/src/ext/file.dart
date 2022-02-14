import 'package:file/file.dart';
import 'package:xnx/src/ext/path.dart';
import 'file_system_entity.dart';
import 'string.dart';

//
// Using milliseconds, as microseconds don't work on Windows
//

extension FileExt on File {

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedToSync({File? toFile, DateTime? toLastModified}) {
    var toLastModStamp = (toFile?.lastModifiedStampSync() ??
        toLastModified?.millisecondsSinceEpoch);

    var result = compareLastModifiedStampToSync(toLastModifiedStamp: toLastModStamp);

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedStampToSync({File? toFile, int? toLastModifiedStamp}) {
    var lastModStamp = (lastModifiedStampSync() ?? -1);
    var toLastModStamp = (toFile?.lastModifiedStampSync() ?? toLastModifiedStamp ?? -1);

    var result = (lastModStamp == toLastModStamp ? 0 : (lastModStamp < toLastModStamp ? -1 : 1));

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String formatSize(int fileSize, String format, {int decimals = 2, String? units}) {
    if (fileSize <= 0) {
      return fileSize.toString();
    }

    var divisor = 1;

    switch (format) {
      case 'K':
        divisor = 1024;
        break;
      case 'M':
        divisor = 1024 * 1024;
        break;
      case 'G':
        divisor = 1024 * 1024 * 1024;
        break;
      case 'T':
        divisor = 1024 * 1024 * 1024 * 1024;
        break;
      case 'P':
        divisor = 1024 * 1024 * 1024 * 1024 * 1024;
        break;
      case 'E':
        divisor = 1024 * 1024 * 1024 * 1024 * 1024 * 1024;
        break;
      default:
        break;
    }

    var fileSizeStr = (fileSize / divisor).toStringAsFixed(decimals);

    return (units == null ? fileSizeStr : fileSizeStr + units);
  }

  //////////////////////////////////////////////////////////////////////////////

  static File? getIfExistsSync(String path, {bool canThrow = true, String? description}) {
    final file = (path.isBlank() ? null : Path.fileSystem.file(path));

    if (!(file?.existsSync() ?? false)) {
      if (canThrow) {
        var descEx = (description == null ? 'File' : description + ' file');
        var pathEx = (file == null ? '' : path);
        throw Exception(Path.appendCurDirIfPathIsRelative('$descEx is not found: ', pathEx));
      }
      else {
        return null;
      }
    }

    return file;
  }

  //////////////////////////////////////////////////////////////////////////////

  int? lastModifiedStampSync() {
    final info = statSync();

    if (info.type == FileSystemEntityType.notFound) {
      return null;
    }
    else {
      return info.modified.millisecondsSinceEpoch;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void setTimeSync(DateTime? modified) {
    if (modified == null) {
      return;
    }

    var stat = statSync();

    if (stat.type == FileSystemEntityType.notFound) {
      return;
    }

    var stamp = modified.millisecondsSinceEpoch;

    setLastModifiedSync(modified);
    setLastAccessedSync(modified);

    var newStat = statSync();
    var newStamp = newStat.modified.millisecondsSinceEpoch;

    if (newStamp < stamp) {
      stamp = ((newStamp + Duration.millisecondsPerSecond) - (newStamp % Duration.millisecondsPerSecond));
      modified = DateTime.fromMillisecondsSinceEpoch(stamp);

      setLastModifiedSync(modified);
      newStat = statSync();
      newStamp = newStat.modified.millisecondsSinceEpoch;

      if (newStamp < stamp) {
        stamp += Duration.millisecondsPerSecond;
        modified = DateTime.fromMillisecondsSinceEpoch(stamp);
        setLastModifiedSync(modified);
      }

      setLastAccessedSync(modified);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void setTimeStampSync(int? modified) =>
     setTimeSync((modified == null) || (modified == 0) ? null : DateTime.fromMillisecondsSinceEpoch(modified));

  //////////////////////////////////////////////////////////////////////////////

  static File? truncateIfExistsSync(String path, {bool canThrow = true, String? description}) {
    final file = (path.isBlank() ? null : Path.fileSystem.file(path));

    if (file == null) {
      if (canThrow) {
        var descEx = (description == null ? 'File' : description + ' file');
        throw Exception('$descEx path is empty');
      }
      else {
        return null;
      }
    }

    if (file.existsSync()) {
      file.deleteSync();
    }

    return file;
  }

  //////////////////////////////////////////////////////////////////////////////

  void xferSync(String toPath, {bool isListOnly = false, bool isMove = false, bool isNewerOnly = false, bool isSilent = false}) {
    // Ensuring source file exists

    if (!tryExistsSync()) {
      throw Exception('${isListOnly ? 'Will fail to copy' : 'Copy failed'}, as source file "$path" is not found');
    }

    // Sanity check

    if (Path.equals(path, toPath)) {
      throw Exception('${isListOnly ? 'Will not' : 'Unable to'} copy: source and target are the same: "$path"');
    }

    // Getting destination path and directory, as well as checking what's newer

    var isToDir = Path.fileSystem.directory(toPath).existsSync();
    var isToDirValid = isToDir;
    var toPathEx = (isToDir ? Path.join(toPath, Path.basename(path)) : toPath);
    var toDirName = (isToDir ? toPath : Path.dirname(toPath));

    var lastModStamp = lastModifiedStampSync() ?? 0;

    var toFile = Path.fileSystem.file(toPathEx);
    var toLastModStamp = (toFile.lastModifiedStampSync() ?? 0);

    var canDo = (!isNewerOnly || (lastModStamp < toLastModStamp));

    // Setting operation flag depending on whether the destination is newer or not

    if (!isToDirValid) {
      Path.fileSystem.directory(toDirName).createSync();
    }

    if (isMove) {
      if (canDo) {
        if (!isSilent) {
          print('${isListOnly ? 'Will move' : 'Moving'} file "$path"');
        }
        if (!isListOnly) {
          renameSync(toPathEx);
        }
      }
      else {
        if (!isSilent) {
          print('${isListOnly ? 'Will delete' : 'Deleting'} file "$path"');
        }
        if (!isListOnly) {
          deleteSync();
        }
      }
    }
    else if (canDo) {
      if (!isSilent) {
        print('${isListOnly ? 'Will copy' : 'Copying'} file "$path"');
      }
      if (!isListOnly) {
        copySync(toPathEx);
      }
    }

    if (!isListOnly) {
      toFile.setTimeStampSync(lastModStamp);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}
