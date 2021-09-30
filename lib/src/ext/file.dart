import 'dart:io';
import 'package:file/file.dart';
import 'package:xnx/src/ext/path.dart';
import 'file_system_entity.dart';
import 'string.dart';

extension FileExt on File {
  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final int MCSEC_PER_SEC = 1000000;

  //////////////////////////////////////////////////////////////////////////////

  int? lastModifiedStampSync() {
    final info = statSync();

    if (info.type == FileSystemEntityType.notFound) {
      return null;
    }
    else {
      return info.modified.microsecondsSinceEpoch;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedToSync({File? toFile, DateTime? toLastModified}) {
    var toLastModStamp = (toFile?.lastModifiedStampSync() ??
        toLastModified?.microsecondsSinceEpoch);

    var result =
        compareLastModifiedStampToSync(toLastModifiedStamp: toLastModStamp);

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedStampToSync({File? toFile, int? toLastModifiedStamp}) {
    var lastModStamp = (lastModifiedStampSync() ?? -1);

    var toLastModStamp =
        (toFile?.lastModifiedStampSync() ?? toLastModifiedStamp ?? -1);

    var result = (lastModStamp == toLastModStamp
        ? 0
        : (lastModStamp < toLastModStamp ? -1 : 1));

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static File? getIfExistsSync(String path,
      {bool canThrow = true, String? description}) {
    final file = (path.isBlank() ? null : Path.fileSystem.file(path));

    if (!(file?.existsSync() ?? false)) {
      if (canThrow) {
        var descEx = (description == null ? 'File' : description + ' file');
        var pathEx = (file == null ? '' : path);
        throw Exception('$descEx was not found: "$pathEx"');
      }
      else {
        return null;
      }
    }

    return file;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isNewerThanSync(File toFile) =>
      (compareLastModifiedToSync(toFile: toFile) > 0);

  //////////////////////////////////////////////////////////////////////////////

  void setTimeSync({DateTime? modified, FileStat? stat}) {
    var modifiedEx = (stat?.modified ?? modified);

    if (modifiedEx == null) {
      return;
    }

    setLastModifiedSync(modifiedEx);
    setLastAccessedSync(modifiedEx);

    var newStat = statSync();

    var stamp1 = modifiedEx.microsecondsSinceEpoch;
    var stamp2 = newStat.modified.microsecondsSinceEpoch;

    if (stamp2 < stamp1) {
      stamp1 = ((stamp2 + MCSEC_PER_SEC) - (stamp2 % MCSEC_PER_SEC));
      modifiedEx = DateTime.fromMicrosecondsSinceEpoch(stamp1);

      setLastModifiedSync(modifiedEx);
      newStat = statSync();
      stamp2 = newStat.modified.microsecondsSinceEpoch;

      if (stamp2 < stamp1) {
        stamp1 += MCSEC_PER_SEC;
        modifiedEx = DateTime.fromMicrosecondsSinceEpoch(stamp1);
        setLastModifiedSync(modifiedEx);
      }

      setLastAccessedSync(modifiedEx);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static File? truncateIfExistsSync(String path,
      {bool canThrow = true, String? description}) {
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

  void xferSync(String toPath,
      {bool isMove = false, bool isNewerOnly = false, bool isSilent = false}) {
    // Ensuring source file exists

    if (!tryExistsSync()) {
      throw Exception('Copy failed, as source file "$path" was not found');
    }

    // Sanity check

    if (Path.equals(path, toPath)) {
      throw Exception(
          'Unable to copy: source and target are the same: "$path"');
    }

    // Getting destination path and directory, as well as checking what's newer

    var isToDir = Path.fileSystem.directory(toPath).existsSync();
    var isToDirValid = isToDir;
    var toPathEx = (isToDir ? Path.join(toPath, Path.basename(path)) : toPath);
    var toDirName = (isToDir ? toPath : Path.dirname(toPath));
    var canDo =
        (!isNewerOnly || isNewerThanSync(Path.fileSystem.file(toPathEx)));

    // Setting operation flag depending on whether the destination is newer or not

    if (!isToDirValid) {
      Path.fileSystem.directory(toDirName).createSync();
    }

    if (isMove) {
      if (canDo) {
        if (!isSilent) {
          print('Moving file "$path"');
        }
        renameSync(toPathEx);
      }
      else {
        if (!isSilent) {
          print('Deleting file "$path"');
        }
        deleteSync();
      }
    } else if (canDo) {
      if (!isSilent) {
        print('Copying file "$path"');
      }

      var fromStat = statSync();
      copySync(toPathEx);
      Path.fileSystem.file(toPathEx).setTimeSync(stat: fromStat);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}
