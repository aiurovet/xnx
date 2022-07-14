import 'package:file/file.dart';
import 'package:archive/archive_io.dart';
import 'package:xnx/command.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/ext/string.dart';
import 'package:xnx/ext/file.dart';
import 'package:xnx/ext/file_system_entity.dart';
import 'package:xnx/file_oper.dart';

enum PackType {
  bz2,
  gz,
  tar,
  tarBz2,
  tarGz,
  tarZ,
  zip,
  z,
}

class PackOper {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static final Map<PackType, String> defaultExtensions = { // case-insensitive
    PackType.bz2: '.bz2',
    PackType.gz: '.gz',
    PackType.tar: '.tar',
    PackType.tarBz2: '.tar.bz2',
    PackType.tarGz: '.tar.gz',
    PackType.tarZ: '.tar.Z',
    PackType.z: '.Z',
    PackType.zip: '.zip',
  };

  static const int defaultCompression = Deflate.DEFAULT_COMPRESSION;

  //////////////////////////////////////////////////////////////////////////////
  // Configuration
  //////////////////////////////////////////////////////////////////////////////

  static int compression = defaultCompression;

  //////////////////////////////////////////////////////////////////////////////

  static void archiveSync(PackType? packType, List<String> paths, {bool isListOnly = false, bool isMove = false, bool isSilent = false}) {
    var pathLists = Path.argsToLists(paths, oper: 'archive', isLastSeparate: true);

    if (packType == null) {
      throw Exception('Archive type is not defined');
    }

    var toPath = pathLists[1][0];

    if (toPath.isEmpty) {
      throw Exception('Destination path is not defined');
    }

    final isZip = (packType == PackType.zip);
    final isTar = isPackTypeTar(packType);
    final isTarPacked = (isTar && (packType != PackType.tar));

    var toPathEx = (isTarPacked ? getUnpackPath(packType, toPath, null) :  toPath);
    var toFile = Path.fileSystem.file(toPathEx);
    print('${isListOnly ? 'Will create' : 'Creating'} archive "$toPathEx"');

    var toDir = Path.fileSystem.directory(Path.dirname(toPathEx));
    var hadToDir = toDir.existsSync();

    if (!isListOnly) {
      if (!hadToDir) {
        toDir.createSync(recursive: true);
      }
      else {
        toFile.deleteIfExistsSync();
      }
    }

    TarFileEncoder? tarFileEncoder;
    ZipFileEncoder? zipFileEncoder;

    try {
      tarFileEncoder = (isTar && !isListOnly ? TarFileEncoder() : null);
      tarFileEncoder?.create(toPathEx);

      zipFileEncoder = (isZip && !isListOnly ? ZipFileEncoder() : null);
      zipFileEncoder?.create(toPathEx, level: compression);

      FileOper.listSync(pathLists[0],
        repeats: (isMove ? 2 : 1),
        isSilent: isSilent,
        isSorted: true,
        isMinimal: true,
        listProc: (entities, entityNo, repeatNo, subPath) {
          if (entityNo < 0) { // empty list
            throw Exception(Path.appendCurDirIfPathIsRelative('Source is not found: ', paths[0]));
          }

          var entity = entities[entityNo];
          var isDir = (entity is Directory);
          var isDirOnly = entity.path.endsWith(Path.separator);

          if (repeatNo == 0) {
            if (!isSilent) {
              print('${isListOnly ? 'Will add' : 'Adding'} ${isDir ? 'dir' : 'file'} "${entity.path}"');
            }

            if (!isListOnly) {
              if (isTar) {
                if (isDir) {
                  tarFileEncoder?.addDirectory(entity);
                }
                else if (!isDirOnly) {
                  tarFileEncoder?.addFile(entity as File);
                }
              }
              else if (isZip) {
                if (isDir) {
                  zipFileEncoder?.addDirectory(entity, includeDirName: ((subPath?.isNotEmpty ?? false) || isDirOnly));
                }
                else {
                  zipFileEncoder?.addFile(entity as File);
                }
              }
            }
          }
          else if (isMove && (repeatNo == 1)) {
            if (entity.existsSync()) {
              if (!isSilent) {
                print('${isListOnly ? 'Will delete' : 'Deleting'} ${isDir ? 'dir' : 'file'} "${entity.path}"');
              }
              if (!isListOnly) {
                entity.deleteSync(recursive: true);
              }
            }
          }

          return true;
        }
      );
    }
    catch (e) {
      if (!isListOnly) {
        toFile.deleteIfExistsSync();

        if (!hadToDir) {
          toDir.deleteSync(recursive: true);
        }
      }

      rethrow;
    }
    finally {
      tarFileEncoder?.close();
      zipFileEncoder?.close();
    }

    if (isTarPacked) {
      compressSync(packType, toPathEx, toPath: toPath, isListOnly: isListOnly, isMove: true, isSilent: isSilent);
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String compressSync(PackType packType, String fromPath, {String? toPath, bool isListOnly = false, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExistsSync(fromPath);

    if (fromFile == null) {
      return '';
    }

    final toPathEx = getPackPath(packType, fromPath, toPath);

    if (!isSilent) {
      print('${isListOnly ? 'Will compress' : 'Compressing'} to "$toPathEx"');
    }

    if (!isListOnly) {
      final encoder = _encodeFileSync(packType, fromFile);
      final toFile = FileExt.truncateIfExistsSync(toPathEx);

      if ((encoder != null) && (toFile != null)) {
        toFile.writeAsBytesSync(encoder);
      }
    }

    if (isMove) {
      if (!isSilent) {
        print('${isListOnly ? 'Will remove' : 'Removing'} "${fromFile.path}"');
      }

      if (!isListOnly) {
        fromFile.delete();
      }
    }

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////

  static String getPackPath(PackType packType, String fromPath, String? toPath) {
    if (toPath != null) {
      if ((packType == PackType.zip) || (!toPath.isBlank() && (toPath != fromPath))) {
        return toPath;
      }
    }

    PackType packTypeEx;

    switch (packType) {
      case PackType.tarBz2:
        packTypeEx = PackType.bz2;
        break;
      case PackType.tarGz:
        packTypeEx = PackType.gz;
        break;
      case PackType.tarZ:
        packTypeEx = PackType.z;
        break;
      default:
        packTypeEx = packType;
        break;
    }

    return fromPath + (defaultExtensions[packTypeEx] ?? '');
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

      defaultExtensions.forEach((key, value) {
        final currLen = value.length;

        if ((packTypeByExt == null) || (currLen > maxMatchLen)) {
          if (fileName.endsWith(value.toLowerCase())) {
            maxMatchLen = currLen;
            packTypeByExt = key;
          }
        }
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

    if (packType == PackType.tar) {
      throw Exception('File "$fromPath" is not compressed');
    }

    var fileTitle = Path.basenameWithoutExtension(fromPath);
    var extTar = defaultExtensions[PackType.tar] ?? '';

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
    ((packType == PackType.tar) || (packType == PackType.tarBz2) ||
    (packType == PackType.tarGz) || (packType == PackType.tarZ));

  //////////////////////////////////////////////////////////////////////////////

  static void unarchiveSync(PackType packType, String fromPath, String? toDirName, {bool isListOnly = false, bool isMove = false, bool isSilent = false}) {
    final isTar = isPackTypeTar(packType);
    final isZip = (packType == PackType.zip);

    if (!isTar && !isZip) {
      throw Exception('Archive type is not supported: "$packType"');
    }

    final isTarPack = (isTar && (packType != PackType.tar));
    String fromPathEx;

    if (isTarPack) {
      fromPathEx = uncompressSync(packType, fromPath, toPath: null, isListOnly: isListOnly, isMove: isMove, isSilent: isSilent);
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
      print('${isListOnly ? 'Will extract' : 'Extracting'} from archive "$fromPathEx" to "$toDirName"');
    }

    final toDirExisted = toDir.existsSync();
    final archive = _decodeArchSync((isTarPack ? PackType.tar : packType), fromFileEx);

    if (archive == null) {
      return;
    }

    try {
      if (!toDirExisted && !isListOnly) {
        toDir.createSync(recursive: true);
      }

      final cmd = (Env.isWindows || isTar || isListOnly ? null : Command(isToVar: true));

      for (final entity in archive) {
        if (entity.name.isEmpty) {
          continue;
        }

        final toPath = Path.join(toDirName, entity.name);
        final isFile = entity.isFile;

        if (!isSilent) {
          print('${isListOnly ? 'Will extract' : 'Extracting'} ${isFile ? 'file' : 'dir'} "${entity.name}"');
        }

        if (isFile) {
          if (!isListOnly) {
            Path.fileSystem.directory(Path.dirname(toPath))
              .createSync(recursive: true);

            Path.fileSystem.file(toPath)
              ..createSync(recursive: false)
              ..writeAsBytesSync(entity.content);
          }

          if (cmd != null) {
            if (((entity.mode & 0x49) != 0x00) || // has at least one execution permission
                ((entity.mode & 0x92) != 0x92)) { // doesn't have all write permissions
              cmd.exec(text: 'chmod ${(entity.unixPermissions | 0x100).toRadixString(8)} $toPath');
            }
          }
        }
        else {
          if (!isListOnly) {
            Path.fileSystem.directory(toPath)
              .createSync(recursive: true);
          }
        }
      }

      if (isMove || isTarPack) {
        if (isTarPack) {
          if (!isSilent) {
            print('${isListOnly ? 'Will delete' : 'Deleting'} archive "$fromPathEx"'); // current path
          }
          if (!isListOnly) {
            fromFileEx.deleteSync();
          }
        }

        if (!isTarPack || isMove) {
          if (!isSilent) {
            print('${isListOnly ? 'Will delete' : 'Deleting'} archive "$fromPath"'); // original path
          }
          if (!isListOnly) {
            Path.fileSystem.file(fromPath).deleteIfExistsSync();
          }
        }
      }
    }
    catch (e) {
      if (!isListOnly) {
        if (isTarPack) {
          fromFileEx.deleteIfExistsSync();
        }
        if (!toDirExisted) {
          toDir.deleteSync(recursive: true);
        }
      }

      rethrow;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  static String uncompressSync(PackType packType, String fromPath, {String? toPath, bool isListOnly = false, bool isMove = true, bool isSilent = false}) {
    final fromFile = FileExt.getIfExistsSync(fromPath);

    if (fromFile == null) {
      return '';
    }

    if (!isSilent) {
      print('${isListOnly ? 'Will uncompress' : 'Uncompressing'} "${fromFile.path}"');
    }

    final toPathEx = getUnpackPath(packType, fromPath, toPath);

    if (!isListOnly) {
      final decoder = _decodeFileSync(packType, fromFile);
      final toFile = FileExt.truncateIfExistsSync(toPathEx);

      if ((decoder != null) && (toFile != null)) {
        toFile.writeAsBytesSync(decoder);
      }

      if (isMove) {
        fromFile.delete();
      }
    }

    return toPathEx;
  }

  //////////////////////////////////////////////////////////////////////////////
  // Internal methods
  //////////////////////////////////////////////////////////////////////////////

  static Archive? _decodeArchSync(PackType packType, File file) {
    final bytes = file.readAsBytesSync();

    if (packType == PackType.tar) {
      return TarDecoder().decodeBytes(bytes);
    }
    else if (packType == PackType.zip) {
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
      case PackType.bz2:
      case PackType.tarBz2:
        result = BZip2Decoder().decodeBytes(bytes);
        break;
      case PackType.gz:
      case PackType.tarGz:
        result = GZipDecoder().decodeBytes(bytes);
        break;
      case PackType.z:
      case PackType.tarZ:
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
      case PackType.bz2:
      case PackType.tarBz2:
        result = BZip2Encoder().encode(bytes);
        break;
      case PackType.gz:
      case PackType.tarGz:
        result = GZipEncoder().encode(bytes, level: compression);
        break;
      case PackType.z:
      case PackType.tarZ:
        result = ZLibEncoder().encode(bytes, level: compression);
        break;
      default:
        throw Exception('Unknown archive type to decode: "$packType"');
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

}