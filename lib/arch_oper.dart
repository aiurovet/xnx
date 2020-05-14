import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:doul/ext/string.dart';
import 'package:path/path.dart' as Path;

import 'file_oper.dart';
import 'ext/file.dart';
import 'ext/file_system_entity.dart';

enum ArchType {
  Bz2,
  Gz,
  Tar,
  TarBz2,
  TarGz,
  TarZlib,
  Zip,
  Zlib,
}

class ArchOper {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final Map<ArchType, List<String>> DEFAULT_EXTENSIONS = { // case-insensitive
    ArchType.Bz2: [ '.bz2', ],
    ArchType.Gz: [ '.gz', ],
    ArchType.Tar: [ '.tar', ],
    ArchType.TarBz2: [ '.tar.bz2', '.tbz', ],
    ArchType.TarGz: [ '.tar.gz', '.tgz', ],
    ArchType.TarZlib: [ '.tar.zlib', '.tzl' ],
    ArchType.Zlib: [ '.zlib', ],
    ArchType.Zip: [ '.zip', ],
  };

  //////////////////////////////////////////////////////////////////////////////

  static void archSync({ArchType archType, String fromPath, List<String> fromPaths,
    int start = 0, int end, String toPath, bool isMove = false, bool isSilent = false}) {

    var toPathEx = (toPath ?? fromPaths[end]);

    if (archType == null) {
      throw Exception('Archive type is not defined');
    }

    final isZip = (archType == ArchType.Zip);
    final isTar = isArchTypeTar(archType);
    final isTarPacked = (isTar && (archType != ArchType.Tar));

    if ((fromPath == null) && ((fromPaths == null) || fromPaths.isEmpty)) {
      return;
    }

    String toPathExEx;

    if (isTarPacked) {
      toPathExEx = getUnpackPath(archType, toPathEx, null);
    }
    else {
      toPathExEx = toPathEx;
    }

    var toFile = File(toPathExEx);
    print('Creating archive "${toPathExEx}"');

    var toDir = Directory(Path.dirname(toPathExEx));
    var hadToDir = toDir.existsSync();

    if (!hadToDir) {
      toDir.createSync(recursive: true);
    }
    else {
      toFile.deleteIfExistsSync();
    }

    TarFileEncoder tarFileEncoder;
    ZipFileEncoder zipFileEncoder;

    try {
      tarFileEncoder = (isTar ? TarFileEncoder() : null);
      tarFileEncoder?.create(toPathExEx);

      zipFileEncoder = (isZip ? ZipFileEncoder() : null);
      zipFileEncoder?.create(toPathExEx);

      FileOper.listSync(path: fromPath,
        paths: fromPaths,
        start: start,
        end: end,
        repeats: (isMove ? 2 : 1),
        isSilent: isSilent,
        isSorted: true,
        isMinimal: true,
        listProc: (entities, entityNo, repeatNo, subPath) {
          if (entityNo < 0) { // empty list
            throw Exception('Source was not found: "${fromPath ?? fromPaths[start] ?? StringExt.EMPTY}"');
          }

          var entity = entities[entityNo];
          var isDir = (entity is Directory);
          var isDirOnly = entity.path.endsWith(StringExt.PATH_SEP);

          if (repeatNo == 0) {
            if (!isSilent) {
              print('Adding ${isDir ? 'dir' : 'file'} "${entity.path}"');
            }

            if (isTar) {
              if (isDir) {
                if (isDirOnly) {
                  tarFileEncoder.addDirectory(entity);
                }
                else {
                  tarFileEncoder.addDirectory(entity);
                }
              }
              else {
                tarFileEncoder.addFile(entity);
              }
            }
            else if (isZip) {
              if (isDir) {
                zipFileEncoder.addDirectory(entity, includeDirName: (subPath.isNotEmpty || isDirOnly));
              }
              else {
                zipFileEncoder.addFile(entity);
              }
            }
          }
          else if (isMove && (repeatNo == 1)) {
            if (entity.existsSync()) {
              if (!isSilent) {
                print('Deleting ${isDir ? 'dir' : 'file'} "${entity.path}"');
              }
              entity.deleteSync(recursive: true);
            }
          }

          return true;
        }
      );
    }
    catch (e) {
      toFile.deleteIfExistsSync();

      if (!hadToDir) {
        toDir.deleteSync(recursive: true);
      }

      rethrow;
    }
    finally {
      tarFileEncoder?.close();
      zipFileEncoder?.close();
    }

    if (isTarPacked) {
      packSync(archType, toPathExEx, toPath: toPathEx, isMove: true, isSilent: isSilent);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Archive decodeArchSync(ArchType archType, File file) {
    final bytes = file.readAsBytesSync();

    if (archType == ArchType.Tar) {
      return TarDecoder().decodeBytes(bytes);
    }
    else if (archType == ArchType.Zip) {
      return ZipDecoder().decodeBytes(bytes);
    }
    else {
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<int> decodeFileSync(ArchType archType, File file) {
    final bytes = file.readAsBytesSync();
    List<int> result;

    switch (archType) {
      case ArchType.Bz2:
      case ArchType.TarBz2:
        result = BZip2Decoder().decodeBytes(bytes);
        break;
      case ArchType.Gz:
      case ArchType.TarGz:
        result = GZipDecoder().decodeBytes(bytes);
        break;
      case ArchType.Zlib:
      case ArchType.TarZlib:
        result = ZLibDecoder().decodeBytes(bytes);
        break;
      default:
        throw Exception('Unknown archive type to decode: "${archType ?? StringExt.EMPTY}"');
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<int> encodeFileSync(ArchType archType, File file) {
    final bytes = file.readAsBytesSync();
    List<int> result;

    switch (archType) {
      case ArchType.Bz2:
      case ArchType.TarBz2:
        result = BZip2Encoder().encode(bytes);
        break;
      case ArchType.Gz:
      case ArchType.TarGz:
        result = GZipEncoder().encode(bytes);
        break;
      case ArchType.Zlib:
      case ArchType.TarZlib:
        result = ZLibEncoder().encode(bytes);
        break;
      default:
        throw Exception('Unknown archive type to decode: "${archType ?? StringExt.EMPTY}"');
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static ArchType getArchType(ArchType archType, String path) {
    if (archType != null) {
      return archType;
    }

    if (StringExt.isNullOrBlank(path)) {
      return archType;
    }

    var fileName = Path.basename(path).toLowerCase();

    ArchType archTypeByExt;

    if (!StringExt.isNullOrBlank(fileName)) {
      var maxMatchLen = 0;

      DEFAULT_EXTENSIONS.forEach((key, value) {
          value.forEach((currExt) {
            final currLen = currExt.length;

            if ((archTypeByExt == null) || (currLen > maxMatchLen)) {
              if (fileName.endsWith(currExt)) {
                maxMatchLen = currLen;
                archTypeByExt = key;
              }
            }
        });
      });
    }

    return archTypeByExt;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getPackPath(ArchType archType, String fromPath, String toPath) {
    if (!StringExt.isNullOrBlank(toPath) || (archType == null) || (archType == ArchType.Zip)) {
      return toPath;
    }

    ArchType archTypeEx;

    switch (archType) {
      case ArchType.TarBz2:
        archTypeEx = ArchType.Bz2;
        break;
      case ArchType.TarGz:
        archTypeEx = ArchType.Gz;
        break;
      case ArchType.TarZlib:
        archTypeEx = ArchType.Zlib;
        break;
      default:
        archTypeEx = archType;
        break;
    }

    return fromPath + DEFAULT_EXTENSIONS[archTypeEx][0];
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getUnpackPath(ArchType archType, String fromPath, String toPath) {
    final hasToPath = !StringExt.isNullOrBlank(toPath);

    if ((archType == null) || (archType == ArchType.Tar) || !isArchTypeTar(archType)) {
      return (toPath ?? fromPath);
    }

    if (hasToPath) {
      if (Directory(toPath).existsSync()) {
        return Path.join(toPath, Path.basenameWithoutExtension(fromPath));
      }
      else {
        return toPath;
      }
    }
    else if (isArchTypeTar(archType) && (archType != ArchType.Tar)) {
      var defExt = DEFAULT_EXTENSIONS[ArchType.Tar][0];
      var result = Path.join(Path.dirname(fromPath), Path.basenameWithoutExtension(fromPath));

      if (!result.endsWith(defExt)) {
        result += defExt;
      }

      return result;
    }
    else {
      return fromPath;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isArchTypeTar(ArchType archType) =>
      ((archType == ArchType.Tar) || (archType == ArchType.TarBz2) || (archType == ArchType.TarGz) || (archType == ArchType.TarZlib));

  //////////////////////////////////////////////////////////////////////////////

  static String packSync(ArchType archType, String fromPath, {String toPath, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExists(fromPath);

    if (!isSilent ?? false) {
      print('Packing "${fromFile.path}"');
    }

    final encoder = encodeFileSync(archType, fromFile);
    final toPathEx = getPackPath(archType, fromPath, toPath);
    final toFile = FileExt.truncateIfExists(toPathEx);

    toFile.writeAsBytesSync(encoder);

    if (isMove) {
      fromFile.delete();
    }

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void unarchSync(ArchType archType, String fromPath, String toDirName,
    {bool isMove = false, bool isSilent = false}) {

    isMove = (isMove ?? false);
    isSilent = (isSilent ?? false);

    if (archType == null) {
      throw Exception('Archive type is not defined');
    }

    final isTar = isArchTypeTar(archType);
    final isZip = (archType == ArchType.Zip);

    if (!isTar && !isZip) {
      throw Exception('Archive type is not supported: "${archType}"');
    }

    final isTarPack = (isTar && (archType != ArchType.Tar));
    String fromPathEx;

    if (isTarPack) {
      fromPathEx = unpackSync(archType, fromPath, toPath: null, isMove: isMove, isSilent: isSilent);
    }
    else {
      fromPathEx = fromPath;
    }

    final fromFileEx = FileExt.getIfExists(fromPathEx, description: 'Archive');

    toDirName ??= Path.dirname(fromPathEx);
    final toDir = Directory(toDirName);

    if (!isSilent) {
      print('Extracting from archive "${fromPathEx}" to "${toDirName}"');
    }

    final toDirExisted = toDir.existsSync();
    final archive = decodeArchSync((isTarPack ? ArchType.Tar : archType), fromFileEx);

    try {
      if (!toDirExisted) {
        toDir.createSync(recursive: true);
      }

      for (final entity in archive) {
        final toPath = Path.join(toDirName, entity.name);
        final isFile = entity.isFile;

        if (!isSilent) {
          print('Extracting ${isFile ? 'file' : 'dir'} "${entity.name}"');
        }

        if (isFile) {
          File(toPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(entity.content);
        } else {
          Directory(toPath)
            ..createSync(recursive: true);
        }
      }

      if (isMove || isTarPack) {
        if (isTarPack) {
          if (!isSilent) {
            print('Deleting archive "${fromPathEx}"'); // current path
          }

          fromFileEx.deleteSync();
        }

        if (!isTarPack || isMove) {
          if (!isSilent) {
            print('Deleting archive "${fromPath}"'); // original path
          }

          File(fromPath).deleteIfExistsSync();
        }
      }
    }
    catch (e) {
      if (isTarPack) {
        fromFileEx.deleteIfExistsSync();
      }
      if (!toDirExisted) {
        toDir.deleteSync(recursive: true);
      }

      rethrow;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String unpackSync(ArchType archType, String fromPath, {String toPath, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExists(fromPath);

    if (!isSilent ?? false) {
      print('Unpacking "${fromFile.path}"');
    }

    final decoder = decodeFileSync(archType, fromFile);
    final toPathEx = getUnpackPath(archType, fromPath, toPath);
    final toFile = FileExt.truncateIfExists(toPathEx);

    toFile.writeAsBytesSync(decoder);

    if (isMove) {
      fromFile.delete();
    }

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////

}