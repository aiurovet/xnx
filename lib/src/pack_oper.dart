import 'package:file/file.dart';
import 'package:archive/archive_io.dart';
import 'package:xnx/src/command.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/path.dart';
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
    PackType.TarZlib: [ '.tar.z', '.tz' ],
    PackType.Zlib: [ '.Z', ],
    PackType.Zip: [ '.zip', ],
  };

  static const int DEFAULT_COMPRESSION = Deflate.DEFAULT_COMPRESSION;

  //////////////////////////////////////////////////////////////////////////////
  // Configuration
  //////////////////////////////////////////////////////////////////////////////

  static int compression = DEFAULT_COMPRESSION;

  //////////////////////////////////////////////////////////////////////////////

  static void archiveSync(PackType? packType, List<String> paths, {bool isMove = false, bool isSilent = false}) {
    var pathLists = Path.argsToLists(paths, oper: 'archive', isLastSeparate: true);

    if (packType == null) {
      throw Exception('Archive type is not defined');
    }

    var toPath = pathLists[1][0];

    if (toPath.isEmpty) {
      throw Exception('Destination path is not defined');
    }

    final isZip = (packType == PackType.Zip);
    final isTar = isPackTypeTar(packType);
    final isTarPacked = (isTar && (packType != PackType.Tar));

    var toPathEx = (isTarPacked ? getUnpackPath(packType, toPath, null) :  toPath);
    var toFile = Path.fileSystem.file(toPathEx);
    print('Creating archive "$toPathEx"');

    var toDir = Path.fileSystem.directory(Path.dirname(toPathEx));
    var hadToDir = toDir.existsSync();

    if (!hadToDir) {
      toDir.createSync(recursive: true);
    }
    else {
      toFile.deleteIfExistsSync();
    }

    TarFileEncoder? tarFileEncoder;
    ZipFileEncoder? zipFileEncoder;

    try {
      tarFileEncoder = (isTar ? TarFileEncoder() : null);
      tarFileEncoder?.create(toPathEx);

      zipFileEncoder = (isZip ? ZipFileEncoder() : null);
      zipFileEncoder?.create(toPathEx, level: compression);

      FileOper.listSync(pathLists[0],
        repeats: (isMove ? 2 : 1),
        isSilent: isSilent,
        isSorted: true,
        isMinimal: true,
        listProc: (entities, entityNo, repeatNo, subPath) {
          if (entityNo < 0) { // empty list
            throw Exception('Source was not found: "${paths[0]}"');
          }

          var entity = entities[entityNo];
          var isDir = (entity is Directory);
          var isDirOnly = entity.path.endsWith(Path.separator);

          if (repeatNo == 0) {
            if (!isSilent) {
              print('Adding ${isDir ? 'dir' : 'file'} "${entity.path}"');
            }

            if (isTar) {
              if (isDir) {
                tarFileEncoder?.addDirectory(entity as Directory);
              }
              else if (!isDirOnly) {
                tarFileEncoder?.addFile(entity as File);
              }
            }
            else if (isZip) {
              if (isDir) {
                zipFileEncoder?.addDirectory(entity as Directory, includeDirName: ((subPath?.isNotEmpty ?? false) || isDirOnly));
              }
              else {
                zipFileEncoder?.addFile(entity as File);
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
      compressSync(packType, toPathEx, toPath: toPath, isMove: true, isSilent: isSilent);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String compressSync(PackType packType, String fromPath, {String? toPath, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExistsSync(fromPath);

    if (fromFile == null) {
      return '';
    }

    if (!isSilent) {
      print('Packing "${fromFile.path}"');
    }

    final encoder = _encodeFileSync(packType, fromFile);
    final toPathEx = getPackPath(packType, fromPath, toPath);
    final toFile = FileExt.truncateIfExistsSync(toPathEx);

    if ((encoder != null) && (toFile != null)) {
      toFile.writeAsBytesSync(encoder);
    }

    if (isMove) {
      fromFile.delete();
    }

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getPackPath(PackType packType, String fromPath, String? toPath) {
    if (toPath != null) {
      if ((packType == PackType.Zip) || (!toPath.isBlank() && (toPath != fromPath))) {
        return toPath;
      }
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

    return fromPath + _getFirstDefaultExtension(packTypeEx);
  }

  //////////////////////////////////////////////////////////////////////////////

  static PackType? getPackType(PackType? packType, String? path) {
    if ((packType != null) || (path == null) || path.isBlank()) {
      return packType;
    }

    var fileName = Path.basename(path).toLowerCase();

    PackType? packTypeByExt;

    if (!fileName.isBlank()) {
      var maxMatchLen = 0;

      DEFAULT_EXTENSIONS.forEach((key, value) {
        value.forEach((currExt) {
          final currLen = currExt.length;

          if ((packTypeByExt == null) || (currLen > maxMatchLen)) {
            if (fileName.endsWith(currExt.toLowerCase())) {
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

  static String getUnpackPath(PackType? packType, String fromPath, String? toPath) {
    packType ??= getPackType(packType, fromPath);

    if (packType == null) {
      throw Exception('Undefined uncompressed type');
    }

    if (packType == PackType.Tar) {
      throw Exception('File "$fromPath" is not compressed');
    }

    var fileTitle = Path.basenameWithoutExtension(fromPath);
    var extTar = DEFAULT_EXTENSIONS[PackType.Tar]?[0] ?? '';

    if (isPackTypeTar(packType) && !fileTitle.toLowerCase().endsWith(extTar.toLowerCase())) {
      fileTitle += extTar;
    }

    if ((toPath != null) && !toPath.isBlank() && (toPath != fromPath)) {
      if (Path.fileSystem.directory(toPath).existsSync()) {
        toPath = Path.join(toPath, fileTitle);
      }
    }
    else {
      toPath = Path.join(Path.dirname(fromPath), fileTitle);
    }

    return toPath;
  }

  //////////////////////////////////////////////////////////////////////////////

  static bool isPackTypeTar(PackType packType) =>
    ((packType == PackType.Tar) || (packType == PackType.TarBz2) ||
    (packType == PackType.TarGz) || (packType == PackType.TarZlib));

  //////////////////////////////////////////////////////////////////////////////

  static void unarchiveSync(PackType packType, String fromPath, String? toDirName,
    {bool isMove = false, bool isSilent = false}) {

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

    final fromFileEx = FileExt.getIfExistsSync(fromPathEx, description: 'Archive');

    if (fromFileEx == null) {
      return;
    }

    toDirName ??= Path.dirname(fromPathEx);
    final toDir = Path.fileSystem.directory(toDirName);

    if (!isSilent) {
      print('Extracting from archive "$fromPathEx" to "$toDirName"');
    }

    final toDirExisted = toDir.existsSync();
    final archive = _decodeArchSync((isTarPack ? PackType.Tar : packType), fromFileEx);

    if (archive == null) {
      return;
    }

    try {
      if (!toDirExisted) {
        toDir.createSync(recursive: true);
      }

      final cmd = (Env.isWindows ? null : Command(isSync: true, isToVar: true));

      for (final entity in archive) {
        final toPath = Path.join(toDirName, entity.name);
        final isFile = entity.isFile;

        if (!isSilent) {
          print('Extracting ${isFile ? 'file' : 'dir'} "${entity.name}"');
        }

        if (isFile) {
          Path.fileSystem.directory(Path.dirname(toPath))
            .createSync(recursive: true);

          Path.fileSystem.file(toPath)
            ..createSync(recursive: false)
            ..writeAsBytesSync(entity.content);

          if (cmd != null) {
            if ((entity.mode & 0x49) != 0x00) {
              // Restore execution bits only
              cmd.exec(text: 'chmod ${entity.unixPermissions.toRadixString(8)} $toPath');
            }
          }
        }
        else {
          Path.fileSystem.directory(toPath)
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

          Path.fileSystem.file(fromPath).deleteIfExistsSync();
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

  static String uncompressSync(PackType packType, String fromPath, {String? toPath, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExistsSync(fromPath);

    if (fromFile == null) {
      return '';
    }

    if (!isSilent) {
      print('Unpacking "${fromFile.path}"');
    }

    final decoder = _decodeFileSync(packType, fromFile);
    final toPathEx = getUnpackPath(packType, fromPath, toPath);
    final toFile = FileExt.truncateIfExistsSync(toPathEx);

    if ((decoder != null) && (toFile != null)) {
      toFile.writeAsBytesSync(decoder);
    }

    if (isMove) {
      fromFile.delete();
    }

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Internal methods
  //////////////////////////////////////////////////////////////////////////////

  static Archive? _decodeArchSync(PackType packType, File file) {
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

  static List<int>? _decodeFileSync(PackType packType, File file) {
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
        throw Exception('Unknown archive type to decode: "$packType"');
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static List<int>? _encodeFileSync(PackType packType, File file) {
    final bytes = file.readAsBytesSync();
    List<int>? result;

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
        throw Exception('Unknown archive type to decode: "$packType"');
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String _getFirstDefaultExtension(PackType packType) {
    var lst = DEFAULT_EXTENSIONS[packType];

    if ((lst != null) && lst.isNotEmpty) {
      return lst[0];
    }

    throw Exception('Can\'t find the first default extension for pack type $packType');
  }

  //////////////////////////////////////////////////////////////////////////////

}