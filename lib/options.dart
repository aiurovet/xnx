import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as Path;

import 'package:doul/ext/string.dart';
import 'log.dart';
import 'ext/stdin.dart';

class Options {

  //////////////////////////////////////////////////////////////////////////////

  static final Map<String, Object> HELP = {
    'name': 'help',
    'abbr': 'h',
    'help': 'this help screen',
    'negatable': false,
  };
  static final Map<String, Object> START_DIR = {
    'name': 'dir',
    'abbr': 'd',
    'help': 'startup directory',
    'valueHelp': 'DIR',
    'defaultsTo': '.',
  };
  static final Map<String, Object> CONFIG = {
    'name': 'config',
    'abbr': 'c',
    'help': 'configuration file in json format',
    'valueHelp': 'FILE',
    'defaultsTo': './' + DEF_FILE_NAME,
  };
  static final Map<String, Object> FORCE_CONVERT = {
    'name': 'force',
    'abbr': 'f',
    'help': 'ignore timestamps and force conversion',
    'negatable': false,
  };
  static final Map<String, Object> LIST_ONLY = {
    'name': 'list-only',
    'abbr': 'l',
    'help': 'display all commands, but do not execute those',
    'negatable': false,
  };
  static final Map<String, Object> QUIET = {
    'name': 'quiet',
    'abbr': 'q',
    'help': 'quiet mode (no output except when \"${StringExt.STDOUT_PATH}\" is specified as output)',
    'negatable': false,
  };
  static final Map<String, Object> VERBOSITY = {
    'name': 'verbosity',
    'abbr': 'v',
    'help': 'how much information to show: 0-3',
    'valueHelp': 'LEVEL',
    'defaultsTo': '1',
  };
  static final Map<String, Object> XARGS = {
    'name': 'xargs',
    'abbr': 'x',
    'help': 'treat each plain argument independently (e.g. can pass multiple filenames as arguments)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_COPY = {
    'name': 'copy',
    'help': 'just copy file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_COPY_NEWER = {
    'name': 'copy-newer',
    'help': 'just copy more recently updated file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_DELETE = {
    'name': 'delete',
    'help': 'just delete file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_MKDIR = {
    'name': 'mkdir',
    'help': 'just create directories passed as plain arguments',
    'negatable': false,
  };
  static final Map<String, Object> CMD_MOVE = {
    'name': 'move',
    'help': 'just move file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_MOVE_NEWER = {
    'name': 'move-newer',
    'help': 'just move more recently updated file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_RENAME = {
    'name': 'rename',
    'help': 'just rename a single file or directory to another one, both passed as plain arguments (glob patterns are NOT allowed)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_BZ2 = {
    'name': 'bz2',
    'help': 'just compress a single source file to a single destination BZ2 file (can be combined with --tar)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNBZ2 = {
    'name': 'unbz2',
    'help': 'just decompress a single BZ2 source file to a single destination file (can be combined with --untar)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_GZ = {
    'name': 'gz',
    'help': 'just compress a single source file to a single destination GZ file (can be combined with --tar)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNGZ = {
    'name': 'ungz',
    'help': 'just decompress a single GZ source file to a single destination file (can be combined with --untar)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_TAR = {
    'name': 'tar',
    'help': 'just create a single destination archive file containing source files and/or directories (can be combined with --bz2 or --gz)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNTAR = {
    'name': 'untar',
    'help': 'just untar a single archive file to a destination directory (can be combined with --unbz2 or --ungz)',
    'negatable': false,
  };
  static final Map<String, Object> CMD_ZIP = {
    'name': 'zip',
    'help': 'just zip source files and/or directories to a single destination archive file',
    'negatable': false,
  };
  static final Map<String, Object> CMD_UNZIP = {
    'name': 'unzip',
    'help': 'just unzip single archive file to destination directory',
    'negatable': false,
  };

  //////////////////////////////////////////////////////////////////////////////

  static final String APP_NAME = 'doul';
  static final String FILE_TYPE_CFG = '.json';
  static final String DEF_FILE_NAME = '${APP_NAME}${FILE_TYPE_CFG}';

  static final RegExp RE_OPT_CONFIG = RegExp('^[\\-]([\\-]${CONFIG['name']}|${CONFIG['abbr']})([\\=]|\$)', caseSensitive: true);
  static final RegExp RE_OPT_START_DIR = RegExp('^[\\-]([\\-]${START_DIR['name']}|${START_DIR['abbr']})([\\=]|\$)', caseSensitive: true);

  //////////////////////////////////////////////////////////////////////////////

  bool _asXargs;
  bool get asXargs => _asXargs;

  String _configFilePath;
  String get configFilePath => _configFilePath;

  bool _isForced;
  bool get isForced => _isForced;

  bool _isListOnly;
  bool get isListOnly => _isListOnly;

  List<String> _plainArgs;
  List<String> get plainArgs => _plainArgs;

  String _startDirName;
  String get startDirName => _startDirName;

  //////////////////////////////////////////////////////////////////////////////

  bool get isCmd => (_isCmdCopy || _isCmdCopyNewer || _isCmdDelete || _isCmdMkdir || _isCmdMove || _isCmdMoveNewer ||  isCmdPack || isCmdUnpack);
  bool get isCmdPack => (_isCmdBz2 || _isCmdGz || _isCmdTar || _isCmdZip);
  bool get isCmdUnpack => (_isCmdUnbz2 || _isCmdUngz || _isCmdUntar || _isCmdUnzip);

  //////////////////////////////////////////////////////////////////////////////

  bool _isCmdCopy;
  bool get isCmdCopy => _isCmdCopy;

  bool _isCmdCopyNewer;
  bool get isCmdCopyNewer => _isCmdCopyNewer;

  bool _isCmdDelete;
  bool get isCmdDelete => _isCmdDelete;

  bool _isCmdMkdir;
  bool get isCmdMkdir => _isCmdMkdir;

  bool _isCmdMove;
  bool get isCmdMove => _isCmdMove;

  bool _isCmdMoveNewer;
  bool get isCmdMoveNewer => _isCmdMoveNewer;

  bool _isCmdRename;
  bool get isCmdRename => _isCmdRename;

  //////////////////////////////////////////////////////////////////////////////

  bool _isCmdBz2;
  bool get isCmdBz2 => _isCmdBz2;

  bool _isCmdUnbz2;
  bool get isCmdUnbz2 => _isCmdUnbz2;

  bool _isCmdGz;
  bool get isCmdGz => _isCmdGz;

  bool _isCmdUngz;
  bool get isCmdUngz => _isCmdUngz;

  bool _isCmdTar;
  bool get isCmdTar => _isCmdTar;

  bool _isCmdUntar;
  bool get isCmdUntar => _isCmdUntar;

  bool _isCmdZip;
  bool get isCmdZip => _isCmdZip;

  bool _isCmdUnzip;
  bool get isCmdUnzip => _isCmdUnzip;

  //////////////////////////////////////////////////////////////////////////////

  String getConfigFullPath(List<String> args) {
    for (var arg in args) {
      if (RE_OPT_CONFIG.hasMatch(arg)) {
        return configFilePath.getFullPath();
      }
      if (RE_OPT_START_DIR.hasMatch(arg)) {
        break;
      }
    }

    return Path.join(startDirName, configFilePath).getFullPath();
  }

  //////////////////////////////////////////////////////////////////////////////

  void parseArgs(List<String> args) {
    Log.level = Log.LEVEL_DEFAULT;

    var errMsg = StringExt.EMPTY;
    var isHelp = false;

    _configFilePath = null;
    _startDirName = null;
    _isListOnly = false;

    var isLogLevelSet = false;

    final parser = ArgParser()
      ..addFlag(QUIET['name'], abbr: QUIET['abbr'], help: QUIET['help'], negatable: QUIET['negatable'], callback: (value) {
        if (value) {
          Log.level = Log.LEVEL_SILENT;
          isLogLevelSet = true;
        }
      })
      ..addOption(VERBOSITY['name'], abbr: VERBOSITY['abbr'], help: VERBOSITY['help'], valueHelp: VERBOSITY['valueHelp'], defaultsTo: VERBOSITY['defaultsTo'], callback: (value) {
        if (!isLogLevelSet) {
          Log.userLevel = int.parse(value);
        }
      })
      ..addFlag(XARGS['name'], abbr: XARGS['abbr'], help: XARGS['help'], negatable: XARGS['negatable'], callback: (value) {
        _asXargs = value;
      })
      ..addFlag(HELP['name'], abbr: HELP['abbr'], help: HELP['help'], negatable: HELP['negatable'], callback: (value) {
        isHelp = value;
      })
      ..addFlag(LIST_ONLY['name'], abbr: LIST_ONLY['abbr'], help: LIST_ONLY['help'], negatable: LIST_ONLY['negatable'], callback: (value) {
        _isListOnly = value;
      })
      ..addFlag(FORCE_CONVERT['name'], abbr: FORCE_CONVERT['abbr'], help: FORCE_CONVERT['help'], negatable: FORCE_CONVERT['negatable'], callback: (value) {
        _isForced = value;
      })
      ..addOption(START_DIR['name'], abbr: START_DIR['abbr'], help: START_DIR['help'], valueHelp: START_DIR['valueHelp'], defaultsTo: START_DIR['defaultsTo'], callback: (value) {
        _startDirName = (value == null ? StringExt.EMPTY : (value as String).getFullPath());
      })
      ..addOption(CONFIG['name'], abbr: CONFIG['abbr'], help: CONFIG['help'], valueHelp: CONFIG['valueHelp'], defaultsTo: CONFIG['defaultsTo'], callback: (value) {
        _configFilePath = (value == null ? StringExt.EMPTY : (value as String).adjustPath());
      })
      ..addFlag(CMD_COPY['name'], help: CMD_COPY['help'], negatable: CMD_COPY['negatable'], callback: (value) {
        _isCmdCopy = value;
      })
      ..addFlag(CMD_COPY_NEWER['name'], help: CMD_COPY_NEWER['help'], negatable: CMD_COPY_NEWER['negatable'], callback: (value) {
        _isCmdCopyNewer = value;
      })
      ..addFlag(CMD_MOVE['name'], help: CMD_MOVE['help'], negatable: CMD_MOVE['negatable'], callback: (value) {
        _isCmdMove = value;
      })
      ..addFlag(CMD_MOVE_NEWER['name'], help: CMD_MOVE_NEWER['help'], negatable: CMD_MOVE_NEWER['negatable'], callback: (value) {
        _isCmdMoveNewer = value;
      })
      ..addFlag(CMD_DELETE['name'], help: CMD_DELETE['help'], negatable: CMD_DELETE['negatable'], callback: (value) {
        _isCmdDelete = value;
      })
      ..addFlag(CMD_MKDIR['name'], help: CMD_MKDIR['help'], negatable: CMD_MKDIR['negatable'], callback: (value) {
        _isCmdMkdir = value;
      })
      ..addFlag(CMD_BZ2['name'], help: CMD_BZ2['help'], negatable: CMD_BZ2['negatable'], callback: (value) {
        _isCmdBz2 = value;
      })
      ..addFlag(CMD_UNBZ2['name'], help: CMD_UNBZ2['help'], negatable: CMD_UNBZ2['negatable'], callback: (value) {
        _isCmdUnbz2 = value;
      })
      ..addFlag(CMD_GZ['name'], help: CMD_GZ['help'], negatable: CMD_GZ['negatable'], callback: (value) {
        _isCmdGz = value;
      })
      ..addFlag(CMD_UNGZ['name'], help: CMD_UNGZ['help'], negatable: CMD_UNGZ['negatable'], callback: (value) {
        _isCmdUngz = value;
      })
      ..addFlag(CMD_TAR['name'], help: CMD_TAR['help'], negatable: CMD_TAR['negatable'], callback: (value) {
        _isCmdTar = value;
      })
      ..addFlag(CMD_UNTAR['name'], help: CMD_UNTAR['help'], negatable: CMD_UNTAR['negatable'], callback: (value) {
        _isCmdUntar = value;
      })
      ..addFlag(CMD_ZIP['name'], help: CMD_ZIP['help'], negatable: CMD_ZIP['negatable'], callback: (value) {
        _isCmdZip = value;
      })
      ..addFlag(CMD_UNZIP['name'], help: CMD_UNZIP['help'], negatable: CMD_UNZIP['negatable'], callback: (value) {
        _isCmdUnzip = value;
      })
    ;

    if ((args == null) || args.isEmpty) {
      printUsage(parser);
    }

    try {
      var result = parser.parse(args);

      _plainArgs = <String>[];
      _plainArgs.addAll(result.rest);

      if (_asXargs) {
        var inpArgs = stdin.readAsStringSync().split('\n');

        for (var i = 0, n = inpArgs.length; i < n; i++) {
          if (inpArgs[i].trim().isNotEmpty) {
            _plainArgs.add(inpArgs[i]);
          }
        }
      }
    }
    catch (e) {
      isHelp = true;
      errMsg = e?.toString();
    }

    if (isHelp) {
      printUsage(parser, error: errMsg);
    }

    if (StringExt.isNullOrBlank(_startDirName)) {
      _startDirName = null;
    }

    _startDirName = Path.canonicalize(_startDirName ?? '');

    if (StringExt.isNullOrBlank(_configFilePath)) {
      _configFilePath = DEF_FILE_NAME;
    }

    if (configFilePath != StringExt.STDIN_PATH) {
      if (StringExt.isNullOrBlank(Path.extension(_configFilePath))) {
        _configFilePath = Path.setExtension(_configFilePath, FILE_TYPE_CFG);
      }

      if (!Path.isAbsolute(_configFilePath)) {
        _configFilePath = getConfigFullPath(args);
      }

      var configFile = File(_configFilePath);

      if (!configFile.existsSync()) {
        var dirName = Path.dirname(_configFilePath);
        var fileName = Path.basename(dirName) + FILE_TYPE_CFG;

        _configFilePath = Path.join(dirName, fileName);
      }
    }

    if (!StringExt.isNullOrBlank(_startDirName)) {
        Log.information('Setting current directory to: "${_startDirName}"');
        Directory.current = _startDirName;
    }

    unquotePlainArgs();
  }

  //////////////////////////////////////////////////////////////////////////////

  static void printUsage(ArgParser parser, {String error}) {
    stderr.writeln('''

USAGE:

${APP_NAME} [OPTIONS]

${parser.usage}

See README file for more details or visit https://phrasehacker.wordpress.com/software/doul/
      ''');

    throw Exception(error);
  }

  //////////////////////////////////////////////////////////////////////////////

  void unquotePlainArgs() {
    var newArgs = <String>[];
    var argCount = (_plainArgs?.length ?? 0);

    for (var i = 0; i < argCount; i++) {
      var arg = _plainArgs[i].unquote();

      if (arg.isNotEmpty) {
        newArgs.add(arg);
      }
    }

    _plainArgs = newArgs;
  }

  //////////////////////////////////////////////////////////////////////////////
}
