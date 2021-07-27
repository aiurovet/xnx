import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path_api;
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/ext/file.dart';
import 'package:xnx/src/ext/file_system_entity.dart';
import 'package:xnx/src/file_oper.dart';

enum PackType {
  Bz2,
  Gz,
  Tar,
  TarBz2,
  TarGz,
  TarZlib,
  Zip,
  Zlib,
}

class PackOper {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final Map<PackType, List<String>> DEFAULT_EXTENSIONS = { // case-insensitive
    PackType.Bz2: [ '.bz2', ],
    PackType.Gz: [ '.gz', ],
    PackType.Tar: [ '.tar', ],
    PackType.TarBz2: [ '.tar.bz2', '.tbz', ],
    PackType.TarGz: [ '.tar.gz', '.tgz', ],
    PackType.TarZlib: [ '.tar.zl', '.tzl' ],
    PackType.Zlib: [ '.zl', ],
    PackType.Zip: [ '.zip', ],
  };

  static const int DEFAULT_COMPRESSION = Deflate.DEFAULT_COMPRESSION;

  //////////////////////////////////////////////////////////////////////////////
  // Configuration
  //////////////////////////////////////////////////////////////////////////////

  static int compression = DEFAULT_COMPRESSION;

  //////////////////////////////////////////////////////////////////////////////

  static void archiveSync({PackType packType, String fromPath, List<String> fromPaths,
    int start = 0, int end, String toPath, bool isMove = false, bool isSilent = false}) {

    var toPathEx = (toPath ?? fromPaths[end]);

    if (packType == null) {
      throw Exception('Archive type is not defined');
    }

    final isZip = (packType == PackType.Zip);
    final isTar = isPackTypeTar(packType);
    final isTarPacked = (isTar && (packType != PackType.Tar));

    if ((fromPath == null) && ((fromPaths == null) || fromPaths.isEmpty)) {
      return;
    }

    String toPathExEx;

    if (isTarPacked) {
      toPathExEx = getUnpackPath(packType, toPathEx, null);
    }
    else {
      toPathExEx = toPathEx;
    }

    var toFile = File(toPathExEx);
    print('Creating archive "$toPathExEx"');

    var toDir = Directory(path_api.dirname(toPathExEx));
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
      zipFileEncoder?.create(toPathExEx, level: compression);

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
      compressSync(packType, toPathExEx, toPath: toPathEx, isMove: true, isSilent: isSilent);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static Archive decodeArchSync(PackType packType, File file) {
    final bytes = file.readAsBytesSync();

    if (packType == PackType.Tar) {
      return TarDecoder().decodeBytes(bytes);
    }
    else if (packType == PackType.Zip) {
      return ZipDecoder().decodeBytes(bytes);
    }
    else {
      return null;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<int> decodeFileSync(PackType packType, File file) {
    final bytes = file.readAsBytesSync();
    List<int> result;

    switch (packType) {
      case PackType.Bz2:
      case PackType.TarBz2:
        result = BZip2Decoder().decodeBytes(bytes);
        break;
      case PackType.Gz:
      case PackType.TarGz:
        result = GZipDecoder().decodeBytes(bytes);
        break;
      case PackType.Zlib:
      case PackType.TarZlib:
        result = ZLibDecoder().decodeBytes(bytes);
        break;
      default:
        throw Exception('Unknown archive type to decode: "${packType ?? StringExt.EMPTY}"');
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<int> encodeFileSync(PackType packType, File file) {
    final bytes = file.readAsBytesSync();
    List<int> result;

    switch (packType) {
      case PackType.Bz2:
      case PackType.TarBz2:
        result = BZip2Encoder().encode(bytes);
        break;
      case PackType.Gz:
      case PackType.TarGz:
        result = GZipEncoder().encode(bytes, level: compression);
        break;
      case PackType.Zlib:
      case PackType.TarZlib:
        result = ZLibEncoder().encode(bytes, level: compression);
        break;
      default:
        throw Exception('Unknown archive type to decode: "${packType ?? StringExt.EMPTY}"');
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static PackType getPackType(PackType packType, String path) {
    if (packType != null) {
      return packType;
    }

    if (StringExt.isNullOrBlank(path)) {
      return packType;
    }

    var fileName = path_api.basename(path).toLowerCase();

    PackType packTypeByExt;

    if (!StringExt.isNullOrBlank(fileName)) {
      var maxMatchLen = 0;

      DEFAULT_EXTENSIONS.forEach((key, value) {
          value.forEach((currExt) {
            final currLen = currExt.length;

            if ((packTypeByExt == null) || (currLen > maxMatchLen)) {
              if (fileName.endsWith(currExt)) {
                maxMatchLen = currLen;
                packTypeByExt = key;
              }
            }
        });
      });
    }

    return packTypeByExt;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getPackPath(PackType packType, String fromPath, String toPath) {
    if (!StringExt.isNullOrBlank(toPath) || (packType == null) || (packType == PackType.Zip)) {
      return toPath;
    }

    PackType packTypeEx;

    switch (packType) {
      case PackType.TarBz2:
        packTypeEx = PackType.Bz2;
        break;
      case PackType.TarGz:
        packTypeEx = PackType.Gz;
        break;
      case PackType.TarZlib:
        packTypeEx = PackType.Zlib;
        break;
      default:
        packTypeEx = packType;
        break;
    }

    return fromPath + DEFAULT_EXTENSIONS[packTypeEx][0];
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getUnpackPath(PackType packType, String fromPath, String toPath) {
    final hasToPath = !StringExt.isNullOrBlank(toPath);

    if ((packType == null) || (packType == PackType.Tar) || !isPackTypeTar(packType)) {
      return (toPath ?? fromPath);
    }

    if (hasToPath) {
      if (Directory(toPath).existsSync()) {
        return path_api.join(toPath, path_api.basenameWithoutExtension(fromPath));
      }
      else {
        return toPath;
      }
    }
    else if (isPackTypeTar(packType) && (packType != PackType.Tar)) {
      var defExt = DEFAULT_EXTENSIONS[PackType.Tar][0];
      var result = path_api.join(path_api.dirname(fromPath), path_api.basenameWithoutExtension(fromPath));

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

  static bool isPackTypeTar(PackType packType) =>
      ((packType == PackType.Tar) || (packType == PackType.TarBz2) || (packType == PackType.TarGz) || (packType == PackType.TarZlib));

  //////////////////////////////////////////////////////////////////////////////

  static String compressSync(PackType packType, String fromPath, {String toPath, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExists(fromPath);

    if (!isSilent ?? false) {
      print('Packing "${fromFile.path}"');
    }

    final encoder = encodeFileSync(packType, fromFile);
    final toPathEx = getPackPath(packType, fromPath, toPath);
    final toFile = FileExt.truncateIfExists(toPathEx);

    toFile.writeAsBytesSync(encoder);

    if (isMove) {
      fromFile.delete();
    }

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void unarchiveSync(PackType packType, String fromPath, String toDirName,
    {bool isMove = false, bool isSilent = false}) {

    isMove = (isMove ?? false);
    isSilent = (isSilent ?? false);

    if (packType == null) {
      throw Exception('Archive type is not defined');
    }

    final isTar = isPackTypeTar(packType);
    final isZip = (packType == PackType.Zip);

    if (!isTar && !isZip) {
      throw Exception('Archive type is not supported: "$packType"');
    }

    final isTarPack = (isTar && (packType != PackType.Tar));
    String fromPathEx;

    if (isTarPack) {
      fromPathEx = uncompressSync(packType, fromPath, toPath: null, isMove: isMove, isSilent: isSilent);
    }
    else {
      fromPathEx = fromPath;
    }

    final fromFileEx = FileExt.getIfExists(fromPathEx, description: 'Archive');

    toDirName ??= path_api.dirname(fromPathEx);
    final toDir = Directory(toDirName);

    if (!isSilent) {
      print('Extracting from archive "$fromPathEx" to "$toDirName"');
    }

    final toDirExisted = toDir.existsSync();
    final archive = decodeArchSync((isTarPack ? PackType.Tar : packType), fromFileEx);

    try {
      if (!toDirExisted) {
        toDir.createSync(recursive: true);
      }

      for (final entity in archive) {
        final toPath = path_api.join(toDirName, entity.name);
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
            .createSync(recursive: true);
        }
      }

      if (isMove || isTarPack) {
        if (isTarPack) {
          if (!isSilent) {
            print('Deleting archive "$fromPathEx"'); // current path
          }

          fromFileEx.deleteSync();
        }

        if (!isTarPack || isMove) {
          if (!isSilent) {
            print('Deleting archive "$fromPath"'); // original path
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

  static String uncompressSync(PackType packType, String fromPath, {String toPath, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExists(fromPath);

    if (!isSilent ?? false) {
      print('Unpacking "${fromFile.path}"');
    }

    final decoder = decodeFileSync(packType, fromFile);
    final toPathEx = getUnpackPath(packType, fromPath, toPath);
    final toFile = FileExt.truncateIfExists(toPathEx);

    toFile.writeAsBytesSync(decoder);

    if (isMove) {
      fromFile.delete();
    }

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////

}