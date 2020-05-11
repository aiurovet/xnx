import 'dart:io';
import 'package:path/path.dart' as Path;
import 'string.dart';

extension FileExt on File {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final int _FILE_TIME_PRECISION_MCSEC = 1000000;

  //////////////////////////////////////////////////////////////////////////////

  void deleteIfExistsSync() {
    if (existsSync()) {
      deleteSync(recursive: true);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int lastModifiedSecSync() {
    var fileStat = statSync();

    if (fileStat.type == FileSystemEntityType.notFound) {
      return null;
    }
    else {
      var result = (fileStat.modified.microsecondsSinceEpoch);
      result -= (result % _FILE_TIME_PRECISION_MCSEC);

      return result;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedToSync(File toFile) {
    var toLastMod = toFile?.lastModifiedSecSync();

    return compareLastModifiedSecToSync(toLastMod);
  }

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedSecToSync(int toLastMod) {
    var lastMod = lastModifiedSecSync();

    if (lastMod == null) {
      return -1;
    }

    if (toLastMod == null) {
      return 1;
    }

    var lastModEx = (lastMod - (lastMod % _FILE_TIME_PRECISION_MCSEC));
    var toLastModEx = (toLastMod - (toLastMod % _FILE_TIME_PRECISION_MCSEC));

    if (lastModEx < toLastModEx) {
      return -1;
    }

    if (lastModEx == toLastModEx) {
      return 0;
    }

    return 1;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isNewerThanSync(File toFile) {
    return (compareLastModifiedToSync(toFile) > 0);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isSamePath(String toPath) {
    var pathEx = (Platform.isWindows ? path.toUpperCase() : path).getFullPath();
    var toPathEx = (Platform.isWindows ? toPath.toUpperCase() : toPath).getFullPath();

    return (pathEx.compareTo(toPathEx) == 0);
  }

  //////////////////////////////////////////////////////////////////////////////

  void xferSync(String toPath, {bool move = false, bool newerOnly = false, bool silent = false}) {
    // Ensuring source file exists

    if (!existsSync()) {
      if (silent) {
        return;
      }
      else {
        throw Exception('Copy failed, as source file "${path}" was not found');
      }
    }

    // Sanity check

    if (isSamePath(toPath)) {
      if (silent) {
        return;
      }
      else {
        throw Exception('Unable to copy: source and target are the same: "${path}"');
      }
    }

    // Getting destination path and directory, as well as checking what's newer

    var isToDir = Directory(toPath).existsSync();
    var isToDirValid = isToDir;
    var toPathEx = (isToDir ? Path.join(toPath, Path.basename(path)) : toPath);
    var toDirName = (isToDir ? toPath : Path.dirname(toPath));
    var canDo = (!newerOnly || isNewerThanSync(File(toPathEx)));

    // Setting operation flag depending on whether the destination is newer or not

    if (!isToDirValid) {
      Directory(toDirName).createSync();
    }

    if (move) {
      if (canDo) {
        if (!silent) {
          print('Moving file "${path}"');
        }
        renameSync(toPathEx);
      }
      else {
        if (!silent) {
          print('Deleting file "${path}"');
        }
        deleteSync();
      }
    }
    else if (canDo) {
      if (!silent) {
        print('Copying file "${path}"');
      }

      var fromStat = statSync();

      copySync(toPathEx);

      var toFile = File(toPathEx);

      toFile.setLastModifiedSync(fromStat.modified);
      toFile.setLastAccessedSync(fromStat.accessed);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}