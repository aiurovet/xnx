import 'dart:io';
import 'package:path/path.dart' as Path;
import 'string.dart';

extension FileExt on File {
  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final int _FAT16_FILE_TIME_PRECISION_MCSEC = 2000000;

  //////////////////////////////////////////////////////////////////////////////

  void deleteIfExistsSync() {
    if (existsSync()) {
      deleteSync(recursive: true);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int lastModifiedMcsec() {
    var fileStat = statSync();

    if (fileStat.type == FileSystemEntityType.notFound) {
      return null;
    }
    else {
      return fileStat.modified.microsecondsSinceEpoch;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedTo(File toFile) {
    var toLastMod = toFile?.lastModifiedMcsec();

    return compareLastModifiedMcsecTo(toLastMod);
  }

  //////////////////////////////////////////////////////////////////////////////

  int compareLastModifiedMcsecTo(int toLastMod) {
    var lastMod = lastModifiedMcsec();

    if (lastMod == null) {
      return -1;
    }

    if (toLastMod == null) {
      return 1;
    }

    if ((lastMod % _FAT16_FILE_TIME_PRECISION_MCSEC) == 0) {
      toLastMod -= (toLastMod % _FAT16_FILE_TIME_PRECISION_MCSEC);
    }
    else if ((toLastMod % _FAT16_FILE_TIME_PRECISION_MCSEC) == 0) {
      lastMod -= (lastMod % _FAT16_FILE_TIME_PRECISION_MCSEC);
    }

    if (lastMod < toLastMod) {
      return -1;
    }

    if (lastMod == toLastMod) {
      return 0;
    }

    return 1;
  }

  //////////////////////////////////////////////////////////////////////////////

  bool isNewerThan(File toFile) {
    return (compareLastModifiedTo(toFile) > 0);
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
        throw Exception('Copy failed, as source file was not found: "${path}"');
      }
    }

    // Sanity check

    if (isSamePath(toPath)) {
      if (silent) {
        return;
      }
      else {
        throw Exception('Unable to copy: source and target are the same: "${path}" and "${toPath}"');
      }
    }

    // Getting destination path and directory, as well as checking what's newer

    var isToDir = Directory(toPath).existsSync();
    var isToDirValid = isToDir;
    var toPathEx = (isToDir ? Path.join(toPath, Path.basename(path)) : toPath);
    var toDirName = (isToDir ? toPath : Path.dirname(toPath));
    var canDo = (!newerOnly || isNewerThan(File(toPathEx)));

    // Setting operation flag depending on whether the destination is newer or not

    if (!isToDirValid) {
      Directory(toDirName).createSync();
    }

    if (move) {
      if (canDo) {
        renameSync(toPathEx);
      }
      else {
        deleteSync();
      }
    }
    else if (canDo) {
      copySync(toPathEx);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

}