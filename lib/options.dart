import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as Path;

import 'package:doul/ext/string.dart';
import 'log.dart';
import 'ext/directory.dart';
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

  //////////////////////////////////////////////////////////////////////////////

  static final String APP_NAME = 'doul';
  static final String FILE_TYPE_CFG = '.json';
  static final String DEF_FILE_NAME = '${APP_NAME}${FILE_TYPE_CFG}';

  static final RegExp RE_OPT_CONFIG = RegExp('^[\\-]([\\-]${CONFIG['name']}|${CONFIG['abbr']})([\\=]|\$)', caseSensitive: true);
  static final RegExp RE_OPT_START_DIR = RegExp('^[\\-]([\\-]${START_DIR['name']}|${START_DIR['abbr']})([\\=]|\$)', caseSensitive: true);

  //////////////////////////////////////////////////////////////////////////////

  static bool asXargs;
  static String configFilePath;
  static bool isForced;
  static bool isListOnly;
  static List<String> plainArgs;
  static String startDirName;

  //////////////////////////////////////////////////////////////////////////////

  static String getConfigFullPath(List<String> args) {
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

  static void expandPlainArgs() {
    var argCount = plainArgs.length;

    if (argCount <= 0) {
      return;
    }

    var newArgs = <String>[];
    var reApos = RegExp(r"^\'|\'$");
    var reWild = RegExp(r'[\*\?]');
    var reEscW = RegExp(StringExt.ESC_CHAR_ESC + r'([\*\?' + StringExt.ESC_CHAR_ESC + '])');

    for (var i = 0; i < argCount; i++) {
      var arg = plainArgs[i];

      if (reApos.hasMatch(arg)) {
        arg = arg.replaceAll(reApos, StringExt.EMPTY);
      }
      else {
        var checkWild = arg.replaceAll(reEscW, '');

        arg = arg.replaceAllMapped(reEscW, (match) {
          return match.group(1);
        });

        if (reWild.hasMatch(checkWild)) {
          var fileList = Directory.current.pathListSync(arg);

          if ((fileList?.length ?? 0) > 0) {
            newArgs.addAll(fileList);
          }
          continue;
        }
      }

      if (arg.isNotEmpty) {
        newArgs.add(arg);
      }
    }

    plainArgs = newArgs;
  }

  //////////////////////////////////////////////////////////////////////////////

  static void parseArgs(List<String> args) {
    Log.level = Log.LEVEL_DEFAULT;

    var errMsg = StringExt.EMPTY;
    var isHelp = false;

    configFilePath = null;
    startDirName = null;
    isListOnly = false;

    var isLogLevelSet = false;

    final parser = ArgParser()
      ..addFlag(Options.QUIET['name'], abbr: Options.QUIET['abbr'], help: Options.QUIET['help'], negatable: Options.QUIET['negatable'], callback: (value) {
        if (value) {
          Log.level = Log.LEVEL_SILENT;
          isLogLevelSet = true;
        }
      })
      ..addOption(Options.VERBOSITY['name'], abbr: Options.VERBOSITY['abbr'], help: Options.VERBOSITY['help'], valueHelp: Options.VERBOSITY['valueHelp'], defaultsTo: Options.VERBOSITY['defaultsTo'], callback: (value) {
        if (!isLogLevelSet) {
          Log.userLevel = int.parse(value);
        }
      })
      ..addFlag(Options.XARGS['name'], abbr: Options.XARGS['abbr'], help: Options.XARGS['help'], negatable: Options.XARGS['negatable'], callback: (value) {
        asXargs = value;
      })
      ..addFlag(Options.HELP['name'], abbr: Options.HELP['abbr'], help: Options.HELP['help'], negatable: Options.HELP['negatable'], callback: (value) {
        isHelp = value;
      })
      ..addFlag(Options.LIST_ONLY['name'], abbr: Options.LIST_ONLY['abbr'], help: Options.LIST_ONLY['help'], negatable: Options.LIST_ONLY['negatable'], callback: (value) {
        isListOnly = value;
      })
      ..addFlag(Options.FORCE_CONVERT['name'], abbr: Options.FORCE_CONVERT['abbr'], help: Options.FORCE_CONVERT['help'], negatable: Options.FORCE_CONVERT['negatable'], callback: (value) {
        isForced = value;
      })
      ..addOption(Options.START_DIR['name'], abbr: Options.START_DIR['abbr'], help: Options.START_DIR['help'], valueHelp: Options.START_DIR['valueHelp'], defaultsTo: Options.START_DIR['defaultsTo'], callback: (value) {
        startDirName = (value == null ? StringExt.EMPTY : (value as String).getFullPath());
      })
      ..addOption(Options.CONFIG['name'], abbr: Options.CONFIG['abbr'], help: Options.CONFIG['help'], valueHelp: Options.CONFIG['valueHelp'], defaultsTo: Options.CONFIG['defaultsTo'], callback: (value) {
        configFilePath = (value == null ? StringExt.EMPTY : (value as String).adjustPath());
      })
    ;

    if ((args == null) || args.isEmpty) {
      Options.printUsage(parser);
    }

    try {
      var result = parser.parse(args);

      plainArgs = <String>[];
      plainArgs.addAll(result.rest);

      if (asXargs) {
        var inpArgs = stdin.readAsStringSync().split('\n');

        for (var i = 0, n = inpArgs.length; i < n; i++) {
          if (inpArgs[i].trim().isNotEmpty) {
            plainArgs.add(inpArgs[i]);
          }
        }
      }
    }
    catch (e) {
      isHelp = true;
      errMsg = e?.toString();
    }

    if (isHelp) {
      Options.printUsage(parser, error: errMsg);
    }

    if (StringExt.isNullOrBlank(startDirName)) {
      startDirName = null;
    }

    startDirName = Path.canonicalize(startDirName ?? '');

    if (StringExt.isNullOrBlank(configFilePath)) {
      configFilePath = DEF_FILE_NAME;
    }

    if (configFilePath != StringExt.STDIN_PATH) {
      if (StringExt.isNullOrBlank(Path.extension(configFilePath))) {
        configFilePath = Path.setExtension(configFilePath, FILE_TYPE_CFG);
      }

      if (!Path.isAbsolute(configFilePath)) {
        configFilePath = getConfigFullPath(args);
      }

      var configFile = File(configFilePath);

      if (!configFile.existsSync()) {
        var dirName = Path.dirname(configFilePath);
        var fileName = Path.basename(dirName) + FILE_TYPE_CFG;

        configFilePath = Path.join(dirName, fileName);
      }
    }

    if (!StringExt.isNullOrBlank(startDirName)) {
        Log.information('Setting current directory to: "${startDirName}"');
        Directory.current = startDirName;
    }

    expandPlainArgs();
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
}
