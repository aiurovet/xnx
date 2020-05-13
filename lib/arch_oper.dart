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
  TarZ,
  Z,
  Zip
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
    ArchType.TarZ: [ '.tar.z', ],
    ArchType.Z: [ '.z', ],
    ArchType.Zip: [ '.zip', ],
  };

  //////////////////////////////////////////////////////////////////////////////

  static void archSync({String fromPath, List<String> fromPaths,
    int start = 0, int end, String toPath, ArchType archType,
    bool isMove = false, bool isSilent = false}) {

    var toPathEx = (toPath ?? fromPaths[end]);

    if (archType == null) {
      archType = getDefaultArchType(toPathEx);

      if (archType == null) {
        throw Exception('Archive type is not defined');
      }
    }

    final isZip = (archType == ArchType.Zip);
    final isTarOnly = (archType == ArchType.Tar);
    final isTar = isArchTypeTar(archType);

    if ((fromPath == null) && ((fromPaths == null) || fromPaths.isEmpty)) {
      return;
    }

    String toPathExEx;

    if (isTar && !isTarOnly) {
      toPathExEx = getUnpackPath(toPathEx, null, archType);
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

          if (repeatNo == 0) {
            if (!isSilent) {
              print('Adding ${isDir ? 'dir' : 'file'} "${entity.path}"');
            }

            if (isTar) {
              if (isDir) {
                tarFileEncoder.addDirectory(entity);
              }
              else {
                tarFileEncoder.addFile(entity);
              }
            }
            else if (isZip) {
              if (isDir) {
                zipFileEncoder.addDirectory(
                    entity, includeDirName: subPath.isNotEmpty);
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

    if (!isSilent) {
      print(StringExt.EMPTY);
    }

    if (isTar && !isTarOnly) {
      packSync(toPathExEx, archType: archType, toPath: toPathEx, isMove: true, isSilent: isSilent);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Archive decodeArchSync(File file, ArchType archType) {
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

  static List<int> decodeFileSync(File file, ArchType archType) {
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
      case ArchType.Z:
      case ArchType.TarZ:
        result = ZLibDecoder().decodeBytes(bytes);
        break;
      default:
        throw Exception('Unknown archive type to decode: "${archType ?? StringExt.EMPTY}"');
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<int> encodeFileSync(File file, ArchType archType) {
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
      case ArchType.Z:
      case ArchType.TarZ:
        result = ZLibEncoder().encode(bytes);
        break;
      default:
        throw Exception('Unknown archive type to decode: "${archType ?? StringExt.EMPTY}"');
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static ArchType getDefaultArchType(String path, {ArchType defArchType}) {
    var pathExt = (path == null ? null : Path.extension(path).toLowerCase());

    if (StringExt.isNullOrBlank(pathExt)) {
      return defArchType;
    }

    ArchType archType;

    DEFAULT_EXTENSIONS.forEach((key, value) {
      if (archType == null) {
        value.forEach((ext) {
          if (archType == null) {
            if (pathExt == ext) {
              archType = key;
            }
          }
        });
      }
    });

    return (archType ?? defArchType);
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getPackPath(String fromPath, String toPath, ArchType archType) {
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
      case ArchType.TarZ:
        archTypeEx = ArchType.Z;
        break;
      default:
        archTypeEx = archType;
        break;
    }

    return fromPath + DEFAULT_EXTENSIONS[archTypeEx][0];
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getUnpackPath(String fromPath, String toPath, ArchType archType) {
    if (!StringExt.isNullOrBlank(toPath) || (archType == null) || (archType == ArchType.Zip)) {
      return toPath;
    }

    final defExt = DEFAULT_EXTENSIONS[archType][0];
    final newLen = (fromPath.length - defExt.length);

    if (fromPath.toLowerCase().endsWith(defExt)) {
      return fromPath.substring(0, newLen);
    }
    else if (isArchTypeTar(archType)) {
      return fromPath.substring(0, newLen) + DEFAULT_EXTENSIONS[ArchType.Tar][0];
    }
    else {
      return toPath;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isArchTypeTar(ArchType archType) =>
      ((archType == ArchType.Tar) || (archType == ArchType.TarBz2) || (archType == ArchType.TarGz) || (archType == ArchType.TarZ));

  //////////////////////////////////////////////////////////////////////////////

  static String packSync(String fromPath, {ArchType archType, String toPath, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExists(fromPath);
    final archTypeEx = (archType ?? getDefaultArchType(toPath));

    if (!isSilent ?? false) {
      print('Packing "${fromFile.path}"');
    }

    final encoder = encodeFileSync(fromFile, archTypeEx);
    final toPathEx = getPackPath(fromPath, toPath, archTypeEx);
    final toFile = FileExt.truncateIfExists(toPathEx);

    toFile.writeAsBytesSync(encoder);

    if (isMove) {
      fromFile.delete();
    }

    encoder.clear();

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void unarchSync(String fromPath, String toDirName,
    {ArchType archType, bool isMove = false, bool isSilent = false}) {

    isMove = (isMove ?? false);
    isSilent = (isSilent ?? false);

    if (archType == null) {
      archType = getDefaultArchType(fromPath);

      if (archType == null) {
        throw Exception('Archive type is not defined');
      }
    }

    final isTar = isArchTypeTar(archType);
    final isZip = (archType == ArchType.Zip);

    if (!isTar && !isZip) {
      throw Exception('Archive type is not supported: "${archType}"');
    }

    final isTarPack = (isTar && (archType != ArchType.Tar));
    String fromPathEx;

    if (isTarPack) {
      fromPathEx = unpackSync(fromPath, toPath: null, archType: archType, isMove: isMove, isSilent: isSilent);
    }
    else {
      fromPathEx = fromPath;
    }

    final fromFileEx = FileExt.getIfExists(fromPathEx, description: 'Archive');
    final toDir = Directory(toDirName);

    if (!isSilent) {
      print('Extracting from archive "${fromPathEx}" to "${toDirName}"');
    }

    final toDirExisted = toDir.existsSync();
    final archive = decodeArchSync(fromFileEx, archType);

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
        if (!isSilent) {
          print('Deleting archive "${fromPath}"'); // original path
        }

        if (isTarPack) {
          if (!isSilent) {
            print('Deleting archive "${fromPathEx}"'); // current path
          }

          File(fromPath).deleteIfExistsSync();
        }

        fromFileEx.deleteSync();
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

    if (!isSilent) {
      print(StringExt.EMPTY);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String unpackSync(String fromPath, {ArchType archType, String toPath, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExists(fromPath);
    final archTypeEx = (archType ?? getDefaultArchType(fromPath));

    if (!isSilent ?? false) {
      print('Unacking "${fromFile.path}"');
    }

    final decoder = decodeFileSync(fromFile, archTypeEx);
    final toPathEx = getUnpackPath(fromPath, toPath, archTypeEx);
    final toFile = FileExt.truncateIfExists(toPathEx);

    toFile.writeAsBytesSync(decoder);

    if (isMove) {
      fromFile.delete();
    }

    decoder.clear();

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////

}