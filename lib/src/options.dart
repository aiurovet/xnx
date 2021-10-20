import 'dart:io';
import 'package:collection/collection.dart';
import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:xnx/src/config_file_info.dart';
import 'package:xnx/src/config_file_loader.dart';
import 'package:xnx/src/ext/env.dart';
import 'package:xnx/src/ext/file_system_entity.dart';
import 'package:xnx/src/ext/glob.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/ext/stdin.dart';
import 'package:xnx/src/logger.dart';
import 'package:xnx/src/pack_oper.dart';

class Options {

  //////////////////////////////////////////////////////////////////////////////

  static const String HELP_MIN = '-?';

  static const String ENV_APP_KEY_PREFIX = '_XNX_';
  static const String ENV_USR_KEY_PREFIX = 'XNX_';

  static const String ENV_APPEND_SEP = '${ENV_APP_KEY_PREFIX}APPEND_SEP';
  static const String ENV_COMPRESSION = '${ENV_APP_KEY_PREFIX}COMPRESSION';
  static const String ENV_FORCE = '${ENV_APP_KEY_PREFIX}FORCE';
  static const String ENV_LIST_ONLY = '${ENV_APP_KEY_PREFIX}LIST_ONLY';
  static const String ENV_QUIET = '${ENV_APP_KEY_PREFIX}QUIET';
  static const String ENV_START_DIR = '${ENV_APP_KEY_PREFIX}START_DIR';
  static const String ENV_VERBOSITY = '${ENV_APP_KEY_PREFIX}VERBOSITY';

  //////////////////////////////////////////////////////////////////////////////

  static final Map<String, Object?> APPEND_SEP = {
    'name': 'append-sep',
    'abbr': 's',
    'help': '''append record separator "${ConfigFileLoader.RECORD_SEP}" when filtering input config file (for "${LIST_ONLY['name']}" exclusively),
the application will define environment variable $ENV_APPEND_SEP''',
    'negatable': false,
  };
  static final Map<String, Object?> COMPRESSION = {
    'name': 'compression',
    'abbr': 'p',
    'help': '''compression level for archiving-related operations (${Deflate.BEST_SPEED}..${Deflate.BEST_COMPRESSION}) excepting BZip2,
the application will define environment variable $ENV_COMPRESSION''',
    'valueHelp': 'LEVEL',
    'defaultsTo': null,
  };
  static final Map<String, Object?> CONFIG = {
    'name': 'config',
    'abbr': 'c',
    'help': '''configuration file in json5 format https://json5.org/,
default extension: $FILE_TYPE_CFG''',
    'valueHelp': 'FILE',
    'defaultsTo': null,
  };
  static final Map<String, Object?> EACH = {
    'name': 'each',
    'abbr': 'e',
    'help': '''treat each plain argument independently (e.g. can pass multiple filenames as arguments)
see also -x, --xargs''',
    'negatable': false,
  };
  static final Map<String, Object?> FORCE_CONVERT = {
    'name': 'force',
    'abbr': 'f',
    'help': '''ignore timestamps and force conversion,
the application will define environment variable $ENV_FORCE''',
    'negatable': false,
  };
  static final Map<String, Object?> HELP = {
    'name': 'help',
    'abbr': 'h',
    'help': 'this help screen',
    'negatable': false,
  };
  static final Map<String, Object?> LIST_ONLY = {
    'name': 'list-only',
    'abbr': 'l',
    'help': '''display all commands, but do not execute those; if no command specified, then show config,
the application will define environment variable $ENV_LIST_ONLY''',
    'negatable': false,
  };
  static final Map<String, Object?> QUIET = {
    'name': 'quiet',
    'abbr': 'q',
    'help': '''quiet mode (no output, same as verbosity 0),
the application will define environment variable $ENV_QUIET''',
    'negatable': false,
  };
  static final Map<String, Object?> START_DIR = {
    'name': 'dir',
    'abbr': 'd',
    'help': '''startup directory,
the application will define environment variable $ENV_START_DIR''',
    'valueHelp': 'DIR',
    'defaultsTo': null,
  };
  static final Map<String, Object?> VERBOSITY = {
    'name': 'verbosity',
    'abbr': 'v',
    'help': '''how much information to show: (0-6, or: quiet, errors, normal, warnings, info, debug),
defaults to "${Logger.LEVELS[Logger.LEVEL_DEFAULT]}",
the application will define environment variable $ENV_COMPRESSION,''',
    'valueHelp': 'LEVEL',
    'defaultsTo': null,
  };
  static final Map<String, Object?> WAIT_ALWAYS = {
    'name': 'wait-always',
    'abbr': 'W',
    'help': 'always wait for a user to press <Enter> upon completion',
    'negatable': false,
  };
  static final Map<String, Object?> WAIT_ON_ERR = {
    'name': 'wait-err',
    'abbr': 'w',
    'help': 'wait for a user to press <Enter> upon unsuccessful completion',
    'negatable': false,
  };
  static final Map<String, Object?> XARGS = {
    'name': 'xargs',
    'abbr': 'a',
    'help': 'similar to the above, but reads arguments from stdin\nuseful in a pipe with a file finding command',
    'negatable': false,
  };
  static final Map<String, Object?> XNX = {
    'name': 'xnx',
    'abbr': 'X',
    'help': 'same as -c, --config',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_PRINT = {
    'name': 'print',
    'help': 'just print the arguments to stdout\n',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_COPY = {
    'name': 'copy',
    'help': '''just copy file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_COPY_NEWER = {
    'name': 'copy-newer',
    'help': '''just copy more recently updated file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_DELETE = {
    'name': 'delete',
    'help': '''just delete file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_CREATE_DIR = {
    'name': 'mkdir',
    'help': 'just create directories passed as plain arguments',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_MOVE = {
    'name': 'move',
    'help': '''just move file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_MOVE_NEWER = {
    'name': 'move-newer',
    'help': '''just move more recently updated file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_REMOVE = {
    'name': 'remove',
    'help': 'just the same as --delete\n',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_RENAME = {
    'name': 'rename',
    'help': 'just the same as --move\n',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_RENAME_NEWER = {
    'name': 'rename-newer',
    'help': 'just the same as --move-newer\n',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_BZ2 = {
    'name': 'bz2',
    'help': '''just compress a single source file to a single destination BZip2 file,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_UNBZ2 = {
    'name': 'unbz2',
    'help': '''just decompress a single BZip2 file to a single destination file,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_GZ = {
    'name': 'gz',
    'help': '''just compress a single source file to a single GZip file,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_UNGZ = {
    'name': 'ungz',
    'help': '''just decompress a single GZip file to a single destination file,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_PACK = {
    'name': 'pack',
    'help': '''just compress source files and/or directories to a single destination
archive file depending on its extension, can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_UNPACK = {
    'name': 'unpack',
    'help': '''just decompress a single source archive file to destination files and/or
directories depending on the source extension, can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_TAR = {
    'name': 'tar',
    'help': '''just create a single destination archive file containing source files and/or
directories, can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_UNTAR = {
    'name': 'untar',
    'help': '''just untar a single archive file to a destination directory,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_TAR_BZ2 = {
    'name': 'tarbz2',
    'help': '''just a combination of --tar and --bz2,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_UNTAR_BZ2 = {
    'name': 'untarbz2',
    'help': '''just a combination of --untar and --unbz2,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_TAR_GZ = {
    'name': 'targz',
    'help': '''just a combination of --tar and --gz,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_UNTAR_GZ = {
    'name': 'untargz',
    'help': '''just a combination of --untar and --ungz,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_TAR_ZLIB = {
    'name': 'tarZ',
    'help': '''just a combination of --tar and --Z,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_UNTAR_ZLIB = {
    'name': 'untarZ',
    'help': '''just a combination of --untar and --unZ,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_ZIP = {
    'name': 'zip',
    'help': '''just zip source files and/or directories to a single destination
archive file, can be used with --move to delete the source''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_UNZIP = {
    'name': 'unzip',
    'help': '''just unzip single archive file to destination directory,
can be used with --move to delete the source''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_ZLIB = {
    'name': 'Z',
    'help': '''just compress a single source file to a single Z file,
can be used with --move to delete the source''',
    'negatable': false,
  };
  static final Map<String, Object?> CMD_UNZLIB = {
    'name': 'unZ',
    'help': '''just decompress a single Z file to a single destination file,
can be used with --move to delete the source''',
    'negatable': false,
  };

  //////////////////////////////////////////////////////////////////////////////

  static final String APP_NAME = 'xnx';
  static final String FILE_TYPE_CFG = '.$APP_NAME';
  static final String FILE_MASK_CFG = '${GlobExt.ALL}$FILE_TYPE_CFG';

  static final RegExp RE_OPT_CONFIG = RegExp('^[\\-]([\\-](${CONFIG['name']}|${XNX['name']})|${CONFIG['abbr']})([\\=]|\$)', caseSensitive: true);
  static final RegExp RE_OPT_START_DIR = RegExp('^[\\-]([\\-]${START_DIR['name']}|${START_DIR['abbr']})([\\=]|\$)', caseSensitive: true);

  //////////////////////////////////////////////////////////////////////////////

  bool _asXargs = false;
  bool get asXargs => _asXargs;

  int _compression = PackOper.DEFAULT_COMPRESSION;
  int get compression => _compression;

  ConfigFileInfo _configFileInfo = ConfigFileInfo();
  ConfigFileInfo get configFileInfo => _configFileInfo;

  bool _isAppendSep = false;
  bool get isAppendSep => _isAppendSep;

  bool _isEach = false;
  bool get isEach => _isEach;

  bool _isForced = false;
  bool get isForced => _isForced;
  
  bool _isListOnly = false;
  bool get isListOnly => _isListOnly;
  
  bool _isWaitAlways = false;
  bool get isWaitAlways => _isWaitAlways;
  
  bool _isWaitOnErr = false;
  bool get isWaitOnErr => _isWaitOnErr;

  Logger _logger = Logger();

  List<String> _plainArgs = [];
  List<String> get plainArgs => _plainArgs;

  String _startDirName = '';
  String get startDirName => _startDirName;

  //////////////////////////////////////////////////////////////////////////////

  bool get isCmd => (
    _isCmdPrint ||
    _isCmdCopy || _isCmdCopyNewer ||
    _isCmdDelete || _isCmdCreate ||
    _isCmdMove || _isCmdMoveNewer ||
    _isCmdCompress || isCmdDecompress
  );

  //////////////////////////////////////////////////////////////////////////////

  PackType? _archType;
  PackType? get archType => _archType;

  bool _isCmdCompress = false;
  bool get isCmdCompress => _isCmdCompress;

  bool _isCmdCopy = false;
  bool get isCmdCopy => _isCmdCopy;

  bool _isCmdCopyNewer = false;
  bool get isCmdCopyNewer => _isCmdCopyNewer;

  bool _isCmdDecompress = false;
  bool get isCmdDecompress => _isCmdDecompress;

  bool _isCmdDelete = false;
  bool get isCmdDelete => _isCmdDelete;

  bool _isCmdPrint = false;
  bool get isCmdPrint => _isCmdPrint;

  bool _isCmdCreate = false;
  bool get isCmdCreateDir => _isCmdCreate;

  bool _isCmdMove = false;
  bool get isCmdMove => _isCmdMove;

  bool _isCmdMoveNewer = false;
  bool get isCmdMoveNewer => _isCmdMoveNewer;

  //////////////////////////////////////////////////////////////////////////////

  Options([Logger? log]) {
    if (log != null) {
      _logger = log;
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void addFlag(ArgParser parser, Map<String, Object?> option, void Function(bool)? callback) {
    parser.addFlag(
      option['name']?.toString() ?? '',
      abbr: option['abbr']?.toString(),
      help: option['help']?.toString(),
      negatable: (option['negatable'] as bool?) ?? false,
      callback: callback
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  void addOption(ArgParser parser, Map<String, Object?> option, void Function(String?)? callback) {
    parser.addOption(
      option['name']?.toString() ?? '',
      abbr: option['abbr']?.toString(),
      help: option['help']?.toString(),
      valueHelp: option['valueHelp']?.toString(),
      defaultsTo: option['defaultsTo']?.toString(),
      callback: callback
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  String getConfigFullPath(List<String> args) {
    for (var arg in args) {
      if (RE_OPT_CONFIG.hasMatch(arg)) {
        return Path.getFullPath(_configFileInfo.filePath);
      }
      if (RE_OPT_START_DIR.hasMatch(arg)) {
        break;
      }
    }

    return Path.getFullPath(Path.join(startDirName, configFileInfo.filePath));
  }

  //////////////////////////////////////////////////////////////////////////////

  void parseArgs(List<String> args) {
    var configPath = '';
    var errMsg = '';
    var dirName = '';
    var isHelp = false;

    _configFileInfo.init();
    _startDirName = '';
    _isAppendSep = false;
    _isListOnly = false;
    _isWaitAlways = false;
    _isWaitOnErr = false;

    _isCmdPrint = false;
    _isCmdCompress = false;
    _isCmdDecompress = false;
    _isCmdMove = false;
    _isCmdMoveNewer = false;
    _isCmdDelete = false;

    final parser = ArgParser();

    addFlag(parser, HELP, (value) {
      isHelp = value;
    });
    addOption(parser, CONFIG, (value) {
      if (configPath.isBlank()) {
        configPath = value ?? '';
      }
    });
    addOption(parser, XNX, (value) {
      if (configPath.isBlank()) {
        configPath = value ?? '';
      }
    });
    addOption(parser, START_DIR, (value) {
      dirName = _getString(ENV_START_DIR, value, isPath: true);

      if (!dirName.isBlank()) {
        dirName = Path.getFullPath(dirName);
      }
    });
    addFlag(parser, QUIET, (value) {
      if (_getBool(ENV_QUIET, QUIET, value)) {
        _logger.level = Logger.LEVEL_SILENT;
      }
    });
    addOption(parser, VERBOSITY, (value) {
      if (value != null) {
        var v = _getString(ENV_VERBOSITY, value);
        _logger.levelAsString = v;
      }
    });
    addFlag(parser, EACH, (value) {
      _isEach = value;
    });
    addFlag(parser, XARGS, (value) {
      _asXargs = value;
    });
    addFlag(parser, LIST_ONLY, (value) {
      _isListOnly = _getBool(ENV_LIST_ONLY, LIST_ONLY, value);
    });
    addFlag(parser, APPEND_SEP, (value) {
      _isAppendSep = _getBool(ENV_APPEND_SEP, APPEND_SEP, value);
    });
    addFlag(parser, FORCE_CONVERT, (value) {
      _isForced = _getBool(ENV_FORCE, FORCE_CONVERT, value);
    });
    addOption(parser, COMPRESSION, (value) {
      _compression = _getInt(ENV_COMPRESSION, value, defValue: PackOper.DEFAULT_COMPRESSION);
    });
    addFlag(parser, WAIT_ALWAYS, (value) {
      _isWaitAlways = value;
    });
    addFlag(parser, WAIT_ON_ERR, (value) {
      _isWaitOnErr = value;
    });
    addFlag(parser, CMD_PRINT, (value) {
      _isCmdPrint = value;
    });
    addFlag(parser, CMD_COPY, (value) {
      _isCmdCopy = value;
    });
    addFlag(parser, CMD_COPY_NEWER, (value) {
      _isCmdCopyNewer = value;
    });
    addFlag(parser, CMD_MOVE, (value) {
      if (value) {
        _isCmdMove = value;
      }
    });
    addFlag(parser, CMD_MOVE_NEWER, (value) {
      if (value) {
        _isCmdMoveNewer = value;
      }
    });
    addFlag(parser, CMD_RENAME, (value) {
      if (value) {
        _isCmdMove = value;
      }
    });
    addFlag(parser, CMD_RENAME_NEWER, (value) {
      if (value) {
        _isCmdMoveNewer = value;
      }
    });
    addFlag(parser, CMD_CREATE_DIR, (value) {
      _isCmdCreate = value;
    });
    addFlag(parser, CMD_DELETE, (value) {
      if (value) {
        _isCmdDelete = value;
      }
    });
    addFlag(parser, CMD_REMOVE, (value) {
      if (value) {
        _isCmdDelete = value;
      }
    });
    addFlag(parser, CMD_BZ2, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.Bz2;
      }
    });
    addFlag(parser, CMD_UNBZ2, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.Bz2;
      }
    });
    addFlag(parser, CMD_GZ, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.Gz;
      }
    });
    addFlag(parser, CMD_UNGZ, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.Gz;
      }
    });
    addFlag(parser, CMD_TAR, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.Tar;
      }
    });
    addFlag(parser, CMD_UNTAR, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.Tar;
      }
    });
    addFlag(parser, CMD_TAR_BZ2, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.TarBz2;
      }
    });
    addFlag(parser, CMD_UNTAR_BZ2, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.TarBz2;
      }
    });
    addFlag(parser, CMD_TAR_GZ, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.TarGz;
      }
    });
    addFlag(parser, CMD_UNTAR_GZ, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.TarGz;
      }
    });
    addFlag(parser, CMD_TAR_ZLIB, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.TarZ;
      }
    });
    addFlag(parser, CMD_UNTAR_ZLIB, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.TarZ;
      }
    });
    addFlag(parser, CMD_ZIP, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.Zip;
      }
    });
    addFlag(parser, CMD_UNZIP, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.Zip;
      }
    });
    addFlag(parser, CMD_ZLIB, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.Z;
      }
    });
    addFlag(parser, CMD_UNZLIB, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.Z;
      }
    });
    addFlag(parser, CMD_PACK, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = null;
      }
    });
    addFlag(parser, CMD_UNPACK, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = null;
      }
    });

    if (!_logger.hasLevel) {
      _logger.level = Logger.LEVEL_DEFAULT;
    }

    if (args.isEmpty || args.contains(HELP_MIN)) {
      printUsage(parser);
    }

    try {
      var result = parser.parse(args);

      if (!isCmd) {
        setConfigPathAndStartDirName(configPath, dirName);
      }

      _plainArgs = <String>[];
      _plainArgs.addAll(result.rest);

      if (_asXargs) {
        _isEach = true;

        var inpArgs = stdin.readAsStringSync().split('\n');

        for (var i = 0, n = inpArgs.length; i < n; i++) {
          if (inpArgs[i].trim().isNotEmpty) {
            _plainArgs.add(inpArgs[i]);
          }
        }
      }
    }
    catch (e) {
      isHelp = !_logger.isSilent;
      errMsg = e.toString();
    }

    if (isHelp) {
      printUsage(parser, error: errMsg);
    }

    unquotePlainArgs();
  }

  //////////////////////////////////////////////////////////////////////////////

  static void printUsage(ArgParser parser, {String? error}) {
    stderr.writeln('''
$APP_NAME 0.1.0 (C) Alexander Iurovetski 2020 - 2021

A command-line utility to eXpand text content aNd to eXecute external utilities.

USAGE:

$APP_NAME [OPTIONS]

${parser.usage}

For more details, see README.md
      ''');

    throw Exception(error?.isBlank() ?? true ? HELP['name'] ?? '' : error);
  }

  //////////////////////////////////////////////////////////////////////////////

  void unquotePlainArgs() {
    var newArgs = <String>[];
    var argCount = _plainArgs.length;

    for (var i = 0; i < argCount; i++) {
      var arg = _plainArgs[i].unquote();

      if (arg.isNotEmpty) {
        newArgs.add(arg);
      }
    }

    _plainArgs = newArgs;
  }

  ///////////////////////////////////////////////////////////4///////////////////

  void setConfigPathAndStartDirName(String? configPath, String? dirName) {
    if ((configPath != null) && configPath.isBlank()) {
      configPath = null;
    }

    if ((dirName != null) && dirName.isBlank()) {
      dirName = null;
    }

    if (configPath != null) {
      if (Path.extension(configPath).isBlank()) {
        configPath += FILE_TYPE_CFG;
      }
      configPath = Path.getFullPath(configPath);
    }

    if ((dirName == null) && (configPath != null) && Path.fileSystem.directory(configPath).tryExistsSync()) {
      dirName = configPath;
      configPath = '';
    }

    if (dirName != null) {
      _logger.information('Setting current directory to: "$dirName"');
      Path.fileSystem.currentDirectory = dirName;
    }

    if (dirName != null) {
      _startDirName = dirName;
    }
    else if ((configPath != null)) {
      dirName = Path.dirname(configPath);
      _startDirName = Path.getFullPath(dirName);
    }

    if (_startDirName != dirName) {
      _logger.information('Setting current directory to: "$_startDirName"');
      Path.fileSystem.currentDirectory = _startDirName;
    }

    if ((configPath == null)) {
      var fileName = Path.basename(_startDirName);

      if (fileName.isNotEmpty && !fileName.contains(Path.separator)) {
        configPath = Path.join(_startDirName, fileName + FILE_TYPE_CFG);
      }
    }

    var isConfigPathFound = (configPath?.isNotEmpty ?? false) && Path.fileSystem.file(configPath).tryExistsSync();

    if (!isConfigPathFound) {
      var files = Path.fileSystem.directory(_startDirName).listSync();

      if (files.isNotEmpty) {
        var paths = files.map((x) => x.path).toList()..sort();

        configPath = paths.firstWhereOrNull((x) => Path.extension(x) == FILE_TYPE_CFG);

        isConfigPathFound = !(configPath?.isBlank() ?? true);
      }
    }

    if (!isConfigPathFound) {
      throw Exception('Configuration file not found: "${configPath ?? ''}"');
    }

    _configFileInfo = ConfigFileInfo(configPath);
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _getBool(String envKey, Map<String, Object?> option, bool? value, {bool defValue = false}) {
    var strValue = _getValue(envKey, value?.toString());
    var result = (strValue.isBlank() ? defValue : StringExt.parseBool(strValue));

    var optAbbr = option['abbr']?.toString();

    if (optAbbr?.isNotEmpty ?? false) {
      Env.set(envKey, (result ? '-$optAbbr' : null));
    }

    return result;
  }

  //////////////////////////////////////////////////////////////////////////////

  int _getInt(String envKey, String? value, {int defValue = 0}) {
    var strValue = _getValue(envKey, value);
    var intValue = (int.tryParse(strValue) ?? defValue);

    Env.set(envKey, '$intValue', defValue: 0);

    return intValue;
  }

  //////////////////////////////////////////////////////////////////////////////

  String _getString(String envKey, String? value, {bool isPath = false, String? defValue}) {
    var strValue = _getValue(envKey, value, defValue: defValue);

    if (isPath) {
      strValue = Path.getFullPath(strValue);
    }

    Env.set(envKey, '$strValue', defValue: '');

    return strValue;
  }

  //////////////////////////////////////////////////////////////////////////////

  String _getValue(String envKey, String? value, {String? defValue}) {
    if (value == null) {
      return Env.get(envKey, defValue: defValue);
    }

    return value;
  }

  //////////////////////////////////////////////////////////////////////////////
}
