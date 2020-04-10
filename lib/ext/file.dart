import 'dart:io';

extension FileExt on File {
  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final int FAT_FILE_TIME_PRECISION_MICROSECONDS = 2000000;

  //////////////////////////////////////////////////////////////////////////////

  int lastModifiedInMicrosecondsSinceEpoch({bool isCoarse}) {
    if (!existsSync()) {
      return null;
    }

    var lastMod = lastModifiedSync().microsecondsSinceEpoch;

    if (isCoarse ?? false) {
      lastMod -= (lastMod % FAT_FILE_TIME_PRECISION_MICROSECONDS);
    }

    return lastMod;
  }

  int compareLastModifiedTo(File to, {bool isCoarse}) {
    var toLastMod = to?.lastModifiedInMicrosecondsSinceEpoch(isCoarse: isCoarse);
    var result = compareLastModifiedToInMicrosecondsSinceEpoch(toLastMod, isCoarse: isCoarse);

    return result;
  }

  int compareLastModifiedToInMicrosecondsSinceEpoch(int toLastMod, {bool isCoarse}) {
    var lastMod = lastModifiedInMicrosecondsSinceEpoch(isCoarse: isCoarse);

    if (lastMod == null) {
      return -1;
    }

    if (toLastMod == null) {
      return 1;
    }

    if (lastMod < toLastMod) {
      return -1;
    }

    if (lastMod == toLastMod) {
      return 0;
    }

    return 1;
  }
}