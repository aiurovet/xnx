import 'dart:io';
import 'package:collection/collection.dart';
import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:xnx/config_file_info.dart';
import 'package:xnx/config_file_loader.dart';
import 'package:xnx/ext/env.dart';
import 'package:xnx/ext/file_system_entity.dart';
import 'package:xnx/ext/glob.dart';
import 'package:xnx/ext/path.dart';
import 'package:xnx/ext/string.dart';
import 'package:xnx/ext/stdin.dart';
import 'package:xnx/logger.dart';
import 'package:xnx/escape_mode.dart';
import 'package:xnx/pack_oper.dart';

class Options {

  //////////////////////////////////////////////////////////////////////////////

  static const String appName = 'xnx';
  static const String appConfigName = 'default${fileTypeCfg}config';
  static const String appVersion = '0.1.0';
  static const String fileTypeCfg = '.$appName';
  static const String fileMaskCfg = '${GlobExt.all}$fileTypeCfg';
  static const String helpMin = '-?';

  static const String _envAppKeyPrefix = '_XNX_';

  static const String _envAppendSep = '${_envAppKeyPrefix}APPEND_SEP';
  static const String _envCompression = '${_envAppKeyPrefix}COMPRESSION';
  static const String _envForce = '${_envAppKeyPrefix}FORCE';
  static const String _envListOnly = '${_envAppKeyPrefix}LIST_ONLY';
  static const String _envEscape = '${_envAppKeyPrefix}ESCAPE';
  static const String _envQuiet = '${_envAppKeyPrefix}QUIET';
  static const String _envStartDir = '${_envAppKeyPrefix}START_DIR';
  static const String _envVerbosity = '${_envAppKeyPrefix}VERBOSITY';

  //////////////////////////////////////////////////////////////////////////////

  static const _otherDirPrefix = '~';

  //////////////////////////////////////////////////////////////////////////////

  static final Map<String, Object?> appConfig = {
    'name': 'app-config',
    'abbr': 'c',
    'help': '''$appName application configuration file in JSON5 format https://json5.org/,
defaults to $appConfigName in the directory where $fileTypeCfg file is from''',
    'valueHelp': 'FILE',
    'defaultsTo': null,
  };
  static final Map<String, Object?> appendSep = {
    'name': 'append-sep',
    'abbr': 's',
    'help': '''append record separator "${ConfigFileLoader.recordSep}" when filtering input config file (for "${listOnly['name']}" exclusively),
the application will define environment variable $_envAppendSep''',
    'negatable': false,
  };
  static final Map<String, Object?> compressionLevel = {
    'name': 'compression',
    'abbr': 'p',
    'help': '''compression level for archiving-related operations (${Deflate.BEST_SPEED}..${Deflate.BEST_COMPRESSION}) excepting BZip2,
the application will define environment variable $_envCompression''',
    'valueHelp': 'LEVEL',
    'defaultsTo': null,
  };
  static final Map<String, Object?> each = {
    'name': 'each',
    'abbr': 'e',
    'help': '''treat each plain argument independently (e.g. can pass multiple filenames as arguments)
see also -x/--xargs''',
    'negatable': false,
  };
  static final Map<String, Object?> escape = {
    'name': 'escape',
    'abbr': 'm',
    'help': '''how to escape special characters before the expansion: quotes, xml, html (default: none),
the application will define environment variable $_envEscape''',
    'valueHelp': 'MODE',
    'defaultsTo': null,
  };
  static final Map<String, Object?> expand = {
    'name': 'expand',
    'negatable': false,
  };
  static final Map<String, Object?> forceConvert = {
    'name': 'force',
    'abbr': 'f',
    'help': '''ignore timestamps and force conversion,
the application will define environment variable $_envForce''',
    'negatable': false,
  };
  static final Map<String, Object?> help = {
    'name': 'help',
    'abbr': 'h',
    'help': 'this help screen',
    'negatable': false,
  };
  static final Map<String, Object?> listOnly = {
    'name': 'list-only',
    'abbr': 'l',
    'help': '''display all commands, but do not execute those; if no command specified, then show config,
the application will define environment variable $_envListOnly''',
    'negatable': false,
  };
  static final Map<String, Object?> quiet = {
    'name': 'quiet',
    'abbr': 'q',
    'help': '''quiet mode (no output, same as verbosity 0),
the application will define environment variable $_envQuiet''',
    'negatable': false,
  };
  static final Map<String, Object?> startDir = {
    'name': 'dir',
    'abbr': 'd',
    'help': '''startup directory,
the application will define environment variable $_envStartDir''',
    'valueHelp': 'DIR',
    'defaultsTo': null,
  };
  static final Map<String, Object?> verbosity = {
    'name': 'verbosity',
    'abbr': 'v',
    'help': '''how much information to show: (0-6, or: quiet, errors, normal, warnings, info, debug),
defaults to "${Logger.levels[Logger.levelDefault]}",
the application will define environment variable $_envVerbosity,''',
    'valueHelp': 'LEVEL',
    'defaultsTo': null,
  };
  static final Map<String, Object?> waitAlways = {
    'name': 'wait-always',
    'abbr': 'W',
    'help': 'always wait for a user to press <Enter> upon completion',
    'negatable': false,
  };
  static final Map<String, Object?> waitOnErr = {
    'name': 'wait-err',
    'abbr': 'w',
    'help': 'wait for a user to press <Enter> upon unsuccessful completion',
    'negatable': false,
  };
  static final Map<String, Object?> xargs = {
    'name': 'xargs',
    'abbr': 'a',
    'help': '''similar to -e/--each, but reads arguments from stdin
useful in a pipe with a file path finding command''',
    'negatable': false,
  };
  static final Map<String, Object?> xnx = {
    'name': 'xnx',
    'abbr': 'x',
    'help': '''the actual JSON5 file to process, see https://json5.org/,
default extension: $fileTypeCfg''',
    'valueHelp': 'FILE',
    'defaultsTo': null,
  };
  static final Map<String, Object?> cmdFind = {
    'name': 'find',
    'help': '''just find recursively all files and sub-directories matching the glob pattern
in a given or the current directory and print those to stdout''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdCopy = {
    'name': 'copy',
    'help': '''just copy file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdCopyNewer = {
    'name': 'copy-newer',
    'help': '''just copy more recently updated file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdDelete = {
    'name': 'delete',
    'help': '''just delete file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdCreateDir = {
    'name': 'mkdir',
    'help': 'just create directories passed as plain arguments',
    'negatable': false,
  };
  static final Map<String, Object?> cmdMove = {
    'name': 'move',
    'help': '''just move file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdMoveNewer = {
    'name': 'move-newer',
    'help': '''just move more recently updated file(s) and/or directorie(s) passed as plain argument(s),
glob patterns are allowed''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdPrint = {
    'name': 'print',
    'help': 'just print the arguments to stdout',
    'negatable': false,
  };
  static final Map<String, Object?> cmdPrintCwd = {
    'name': 'pwd',
    'help': 'just print the current working directory to stdout',
    'negatable': false,
  };
  static final Map<String, Object?> cmdPrintEnv = {
    'name': 'env',
    'help': 'just print all environment variables to stdout',
    'negatable': false,
  };
  static final Map<String, Object?> cmdRemove = {
    'name': 'remove',
    'help': 'just the same as --delete',
    'negatable': false,
  };
  static final Map<String, Object?> cmdRename = {
    'name': 'rename',
    'help': 'just the same as --move',
    'negatable': false,
  };
  static final Map<String, Object?> cmdRenameNewer = {
    'name': 'rename-newer',
    'help': 'just the same as --move-newer',
    'negatable': false,
  };
  static final Map<String, Object?> cmdBz2 = {
    'name': 'bz2',
    'help': '''just compress a single source file to a single destination BZip2 file,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdUnBz2 = {
    'name': 'unbz2',
    'help': '''just decompress a single BZip2 file to a single destination file,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdGz = {
    'name': 'gz',
    'help': '''just compress a single source file to a single GZip file,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdUnGz = {
    'name': 'ungz',
    'help': '''just decompress a single GZip file to a single destination file,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdPack = {
    'name': 'pack',
    'help': '''just compress source files and/or directories to a single destination
archive file depending on its extension, can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdUnPack = {
    'name': 'unpack',
    'help': '''just decompress a single source archive file to destination files and/or
directories depending on the source extension, can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdTar = {
    'name': 'tar',
    'help': '''just create a single destination archive file containing source files and/or
directories, can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdUnTar = {
    'name': 'untar',
    'help': '''just untar a single archive file to a destination directory,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdTarBz2 = {
    'name': 'tarbz2',
    'help': '''just a combination of --tar and --bz2,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdUnTarBz2 = {
    'name': 'untarbz2',
    'help': '''just a combination of --untar and --unbz2,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdTarGz = {
    'name': 'targz',
    'help': '''just a combination of --tar and --gz,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdUnTarGz = {
    'name': 'untargz',
    'help': '''just a combination of --untar and --ungz,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdTarZ = {
    'name': 'tarz',
    'help': '''just a combination of --tar and --Z,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdUnTarZ = {
    'name': 'untarz',
    'help': '''just a combination of --untar and --unz,
can be used with --move''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdZip = {
    'name': 'zip',
    'help': '''just zip source files and/or directories to a single destination
archive file, can be used with --move to delete the source''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdUnZip = {
    'name': 'unzip',
    'help': '''just unzip single archive file to destination directory,
can be used with --move to delete the source''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdZ = {
    'name': 'z',
    'help': '''just compress a single source file to a single Z file,
can be used with --move to delete the source''',
    'negatable': false,
  };
  static final Map<String, Object?> cmdUnZ = {
    'name': 'unz',
    'help': '''just decompress a single Z file to a single destination file,
can be used with --move to delete the source''',
    'negatable': false,
  };

  //////////////////////////////////////////////////////////////////////////////

  String _appConfigPath = '';
  String get appConfigPath => _appConfigPath;

  bool _asXargs = false;
  bool get asXargs => _asXargs;

  int _compression = PackOper.defaultCompression;
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

  EscapeMode _escapeMode = EscapeMode.none;
  EscapeMode get escapeMode => _escapeMode;
  set escapeMode(value) => _escapeMode = value;

  List<String> _plainArgs = [];
  List<String> get plainArgs => _plainArgs;

  String _startDirName = '';
  String get startDirName => _startDirName;

  //////////////////////////////////////////////////////////////////////////////

  bool get isCmd => (
    _isCmdFind ||
    _isCmdPrint || _isCmdPrintCwd || _isCmdPrintEnv ||
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

  bool _isCmdFind = false;
  bool get isCmdFind => _isCmdFind;

  bool _isCmdPrint = false;
  bool get isCmdPrint => _isCmdPrint;

  bool _isCmdPrintEnv = false;
  bool get isCmdPrintEnv => _isCmdPrintEnv;

  bool _isCmdPrintCwd = false;
  bool get isCmdPrintCwd => _isCmdPrintCwd;

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

  static void addFlag(ArgParser parser, Map<String, Object?> option, void Function(bool)? callback) {
    parser.addFlag(
      option['name']?.toString() ?? '',
      abbr: option['abbr']?.toString(),
      help: option['help']?.toString(),
      negatable: (option['negatable'] as bool?) ?? false,
      callback: callback
    );
  }

  //////////////////////////////////////////////////////////////////////////////

  static void addOption(ArgParser parser, Map<String, Object?> option, void Function(String?)? callback) {
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

  void parseArgs(List<String> args) {
    var configPath = '';
    var errMsg = '';
    var dirName = '';
    var isHelp = false;

    _appConfigPath = '';
    _escapeMode = EscapeMode.none;
    _configFileInfo.init();
    _startDirName = Path.currentDirectory.path;
    _isAppendSep = false;
    _isListOnly = false;
    _isWaitAlways = false;
    _isWaitOnErr = false;

    _isCmdFind = false;
    _isCmdPrint = false;
    _isCmdPrintEnv = false;
    _isCmdPrintCwd = false;
    _isCmdCompress = false;
    _isCmdDecompress = false;
    _isCmdMove = false;
    _isCmdMoveNewer = false;
    _isCmdDelete = false;

    final parser = ArgParser();

    addFlag(parser, help, (value) {
      if (value) {
        isHelp = true;
      }
    });
    addOption(parser, appConfig, (value) {
      _appConfigPath = value ?? '';
    });
    addOption(parser, xnx, (value) {
      if (configPath.isBlank()) {
        configPath = value ?? '';
      }
    });
    addOption(parser, startDir, (value) {
      dirName = _getString(_envStartDir, value);
    });
    addOption(parser, escape, (value) {
      _escapeMode = parseEscapeMode(value);
    });
    addFlag(parser, quiet, (value) {
      if (_getBool(_envQuiet, quiet, value)) {
        _logger.level = Logger.levelSilent;
      }
    });
    addOption(parser, verbosity, (value) {
      if (value != null) {
        var v = _getString(_envVerbosity, value);
        _logger.levelAsString = v;
      }
    });
    addFlag(parser, each, (value) {
      _isEach = value;
    });
    addFlag(parser, xargs, (value) {
      _asXargs = value;
    });
    addFlag(parser, listOnly, (value) {
      _isListOnly = _getBool(_envListOnly, listOnly, value);
    });
    addFlag(parser, appendSep, (value) {
      _isAppendSep = _getBool(_envAppendSep, appendSep, value);
    });
    addFlag(parser, forceConvert, (value) {
      _isForced = _getBool(_envForce, forceConvert, value);
    });
    addOption(parser, compressionLevel, (value) {
      _compression = _getInt(_envCompression, value, defValue: PackOper.defaultCompression);
    });
    addFlag(parser, waitAlways, (value) {
      _isWaitAlways = value;
    });
    addFlag(parser, waitOnErr, (value) {
      _isWaitOnErr = value;
    });
    addFlag(parser, cmdFind, (value) {
      _isCmdFind = value;
    });
    addFlag(parser, cmdPrint, (value) {
      _isCmdPrint = value;
    });
    addFlag(parser, cmdPrintEnv, (value) {
      _isCmdPrintEnv = value;
    });
    addFlag(parser, cmdPrintCwd, (value) {
      _isCmdPrintCwd = value;
    });
    addFlag(parser, cmdCopy, (value) {
      _isCmdCopy = value;
    });
    addFlag(parser, cmdCopyNewer, (value) {
      _isCmdCopyNewer = value;
    });
    addFlag(parser, cmdMove, (value) {
      if (value) {
        _isCmdMove = value;
      }
    });
    addFlag(parser, cmdMoveNewer, (value) {
      if (value) {
        _isCmdMoveNewer = value;
      }
    });
    addFlag(parser, cmdRename, (value) {
      if (value) {
        _isCmdMove = value;
      }
    });
    addFlag(parser, cmdRenameNewer, (value) {
      if (value) {
        _isCmdMoveNewer = value;
      }
    });
    addFlag(parser, cmdCreateDir, (value) {
      _isCmdCreate = value;
    });
    addFlag(parser, cmdDelete, (value) {
      if (value) {
        _isCmdDelete = value;
      }
    });
    addFlag(parser, cmdRemove, (value) {
      if (value) {
        _isCmdDelete = value;
      }
    });
    addFlag(parser, cmdBz2, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.bz2;
      }
    });
    addFlag(parser, cmdUnBz2, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.bz2;
      }
    });
    addFlag(parser, cmdGz, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.gz;
      }
    });
    addFlag(parser, cmdUnGz, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.gz;
      }
    });
    addFlag(parser, cmdTar, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.tar;
      }
    });
    addFlag(parser, cmdUnTar, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.tar;
      }
    });
    addFlag(parser, cmdTarBz2, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.tarBz2;
      }
    });
    addFlag(parser, cmdUnTarBz2, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.tarBz2;
      }
    });
    addFlag(parser, cmdTarGz, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.tarGz;
      }
    });
    addFlag(parser, cmdUnTarGz, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.tarGz;
      }
    });
    addFlag(parser, cmdTarZ, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.tarZ;
      }
    });
    addFlag(parser, cmdUnTarZ, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.tarZ;
      }
    });
    addFlag(parser, cmdZip, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.zip;
      }
    });
    addFlag(parser, cmdUnZip, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.zip;
      }
    });
    addFlag(parser, cmdZ, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = PackType.z;
      }
    });
    addFlag(parser, cmdUnZ, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = PackType.z;
      }
    });
    addFlag(parser, cmdPack, (value) {
      if (value) {
        _isCmdCompress = value;
        _isCmdDecompress = !value;
        _archType = null;
      }
    });
    addFlag(parser, cmdUnPack, (value) {
      if (value) {
        _isCmdCompress = !value;
        _isCmdDecompress = value;
        _archType = null;
      }
    });

    if (!_logger.hasLevel) {
      _logger.level = Logger.levelDefault;
    }

    if (args.isEmpty || args.contains(helpMin)) {
      printUsage(parser);
    }

    try {
      var result = parser.parse(args);

      if (!isHelp) {
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
    }
    catch (e) {
      errMsg = (isHelp ? '' : e.toString());
      isHelp = true;
    }

    if (isHelp) {
      printUsage(parser, error: errMsg);
    }

    unquotePlainArgs();
  }

  //////////////////////////////////////////////////////////////////////////////

  static EscapeMode parseEscapeMode(String? value, {EscapeMode defValue = EscapeMode.none}) {
    if (value == null) {
      return defValue;
    }

    var valueEx = 'escapemode.${value.toLowerCase()}';

    return EscapeMode.values.firstWhereOrNull((x) => x.toString().toLowerCase() == valueEx) ?? EscapeMode.none;
  }

  //////////////////////////////////////////////////////////////////////////////

  void printUsage(ArgParser parser, {String? error}) {
    if (!_logger.isSilent) {
      stderr.writeln('''
$appName $appVersion (C) Alexander Iurovetski 2020 - 2021

A command-line utility to eXpand text content aNd to eXecute external utilities.

USAGE:

$appName [OPTIONS]

${parser.usage}

For more details, see README.md
'''
      );
    }

    throw Exception(error?.isBlank() ?? true ? help['name'] ?? '' : error);
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

  //////////////////////////////////////////////////////////////////////////////

  void setAppConfigPath() {
    var isFound = false;

    if (_appConfigPath.isNotEmpty) {
      _appConfigPath = Path.getFullPath(_appConfigPath);
      var stat = Path.fileSystem.statSync(_appConfigPath);

      if (stat.type == FileSystemEntityType.file) {
        isFound = true;
      }
      else {
        if (stat.type == FileSystemEntityType.directory) {
          _appConfigPath = Path.join(_appConfigPath, appConfigName);

          if (Path.fileSystem.file(_appConfigPath).existsSync()) {
            isFound = true;
          }
        }
      }
    }

    if (!isFound) {
      var configDirName = Path.dirname(_configFileInfo.filePath);
      _appConfigPath = Path.join(configDirName, appConfigName);

      if (Path.fileSystem.file(_appConfigPath).existsSync()) {
        isFound = true;
      }
      else {
        if (!Path.equals(_startDirName, configDirName)) {
          _appConfigPath = Path.join(_startDirName, appConfigName);

          if (Path.fileSystem.file(_appConfigPath).existsSync()) {
            isFound = true;
          }
        }

        if (!isFound) {
          _appConfigPath = Path.join(Path.dirname(Platform.script.path), appConfigName);

          if (Path.fileSystem.file(_appConfigPath).existsSync()) {
            isFound = true;
          }
        }
      }
    }

    if (_logger.isDebug) {
      _logger.debug('App config file was${isFound ? '' : ' not'} found: "$appConfigPath"\n');
    }

    if (!isFound) {
      _appConfigPath = '';
    }
  }

  //////////////////////////////////////////////////////////////////////////////

  void setConfigPathAndStartDirName(String? configPath, String? dirName) {
    final runDirName = Path.currentDirectory.path;

    if (_logger.isDebug) {
      _logger.debug('''
Run from dir: $runDirName'}
Arg set dir:  ${dirName == null ? StringExt.unknown : '"$dirName"'}
Arg inp file: ${configPath == null ? StringExt.unknown : '"$configPath"'}
''');
    }

    if ((configPath != null) && configPath.isBlank()) {
      configPath = null;
    }

    configPath = _setOtherDir(runDirName, configPath);

    if (configPath != null) {
      if (Path.extension(configPath).isBlank()) {
        configPath += fileTypeCfg;
      }
    }

    dirName = _setOtherDir(runDirName, dirName);

    if ((dirName != null) && !Path.equals(Path.currentDirectory.path, dirName)) {
      _logger.out('cd "$dirName"\n');
      Path.currentDirectoryName = dirName;
    }

    if (configPath != null) {
      configPath = Path.getFullPath(configPath);
    }

    _startDirName = Path.fileSystem.currentDirectory.path;

    if (configPath == null) {
      var fileName = Path.basename(_startDirName);

      if (fileName.isNotEmpty) {
        configPath = Path.join(_startDirName, fileName + fileTypeCfg);

        if (!Path.fileSystem.file(configPath).tryExistsSync()) {
          configPath = null;
        }
      }
    }

    if (configPath == null) {
      var files = Path.fileSystem.directory(_startDirName).listSync();

      if (files.isNotEmpty) {
        var paths = files.map((x) => x.path).toList()..sort();

        configPath = paths.firstWhereOrNull((x) => Path.extension(x) == fileTypeCfg);
      }
    }

    if ((configPath == null) || configPath.isBlank()) {
      throw Exception('No file of type $fileTypeCfg exists in "$_startDirName"');
    }

    configPath = Path.getFullPath(configPath);
    _configFileInfo = ConfigFileInfo(configPath);

    if (_logger.isDebug) {
      _logger.debug('Start dir: "$_startDirName"\nInput file: "${_configFileInfo.filePath}"\n');
    }

    setAppConfigPath();
  }

  //////////////////////////////////////////////////////////////////////////////

  bool _getBool(String envKey, Map<String, Object?> option, bool? value, {bool defValue = false}) {
    var strValue = _getValue(envKey, value?.toString());
    var result = (strValue.isBlank() ? defValue : strValue.parseBool());

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

  String _getString(String envKey, String? value, {String? defValue}) {
    var strValue = _getValue(envKey, value, defValue: defValue);

    Env.set(envKey, strValue, defValue: '');

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

  String? _setOtherDir(String otherDir, String? path) {
    if (path == null) {
      return path;
    }

    final pathLen = path.length;
    final prefixLen = _otherDirPrefix.length;

    if (pathLen < prefixLen) {
      return path;
    }
    if (path.startsWith(_otherDirPrefix)) {
      if ((pathLen != prefixLen) && (path[prefixLen] == Path.separator)) {
        otherDir = Env.getHome();
      }
      return Path.join(otherDir, path.substring(prefixLen));
    }

    return path;
  }

  //////////////////////////////////////////////////////////////////////////////
}
