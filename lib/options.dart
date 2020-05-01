import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as Path;

import 'package:doul/ext/string.dart';
import 'log.dart';

class Options {

  //////////////////////////////////////////////////////////////////////////////

  static final Map<String, Object> HELP = {
    'name': 'help',
    'abbr': 'h',
    'help': 'this help screen',
    'negatable': false,
  };
  static final Map<String, Object> HELP_ALL = {
    'name': 'help-all',
    'abbr': 'H',
    'help': 'display detailed help, including config file format',
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

  static void parseArgs(List<String> args) {
    Log.level = Log.LEVEL_DEFAULT;

    var errMsg = StringExt.EMPTY;
    var isHelp = false;
    var isHelpAll = false;

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
      ..addFlag(Options.HELP_ALL['name'], abbr: Options.HELP_ALL['abbr'], help: Options.HELP_ALL['help'], negatable: Options.HELP_ALL['negatable'], callback: (value) {
        isHelpAll = value;

        if (isHelpAll) {
          isHelp = true;
        }
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

      plainArgs = result.rest;
    }
    catch (e) {
      isHelp = true;
      errMsg = e?.toString();
    }

    if (isHelp) {
      Options.printUsage(parser, isAll: isHelpAll, error: errMsg);
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
  }

  //////////////////////////////////////////////////////////////////////////////

  static void printUsage(ArgParser parser, {bool isAll = false, String error}) {
    stderr.writeln('''

USAGE:

${APP_NAME} [OPTIONS]

${parser.usage}
      ''');

    if (isAll) {
      stderr.writeln('''
##### DETAILS:

**Copyright (C) Alexander Iurovetski, 2020**

Command-line utility to run multiple commands against the same input with
various parameters, and optionally, to expand placeholders inside the input

##### More about command-line options

1.1. Ability to specify top directory as an option comes very handy if you (or
     your team) use(s) different OSes with a single version control repository.
     The noted approach allows to escape the need to specify OS-dependent paths
     in versioned files. You can run the program from specific location or put
     it as an option while running from a batch script, console, or by double-
     clicking a launcher (shortcut) icon. You can specify pathname separators
     in any style (forward slashes as in Unix or backslashes as in Windows),
     the program will replace all of those depending on the OS it is run under.

1.2. If the path to config file (option -c, --config) is not absolute, then its
     absolute path will be resolved using either program startup directory, or
     top directory (option -d, --dir) depending on which option is specified
     first. Yes, this is non-standard, as all options should not depend on the
     order of appearance, but in this case it becomes very handy. Anyway, you
     can avoid the ambiguity by specifying config file using absolute path.

1.3. The program allows you to pass configration by piping some other
     program\'s output. In this case, instead of supplying a filename (or path),
     just put a dash:

     grep -Pi "..." confdir/my.json | doul -c- -d projdir

1.4. Similarly, the program allows you to pass input by piping some other
     program\'s output. In this case, put a dash instead of a filename for
     input:

     { ... "{inp}": "-" ...  } 

1.5. The program also allows you to print the result of expansion to stdout
     rather than to file. In this case, put a dash instead of a filename for
     input (and you won't be able to configure any external command, but rather
     will be confined to the use of a mere pipe):

     { ... "{out}": "-" ... }

##### Configuration file format (see full sample file below)

Originally, this tool was written to produce multiple icon files in PNG format
from a single SVG source. The idea was that knowing width, height, input file
name and location of expected images (icons), it wouldn\'t be too hard to create
some config file, read all that information and run external command with all
required arguments. And in order to resize properly, the input file\'s width and
height had to be adjusted accordingly. However, the application is not really
bound to that particular task and can be used for different purposes. Generally,
it doesn\'t care about specific placeholders and is capable of expanding
anything. Thus, another use case could be to produce multiple configuration
files from a single source template. 

Configuration file is expected in JSON format with the following guidelines:

2.1. The name of the top node name can be anything, it does not matter.

2.2. There should be two sub-nodes: associative array "rename" and an array
     of associative arrays "action".

2.3. The sub-node "rename" should define case-sensitive translations for the
     pre-defined placeholders (see above). The key is a pre-defined placeholder,
     and the value is the placeholder to use instead. As you can see, this can
     make config file less verbose and easier to read. These placeholders are
     self-descriptive, except the ones containing \'exp-\' in their name. The
     "{exp-env}" means that by setting its value to true or to false
     you allow or disallow expansion of environment variables, and the
     "{exp-inp}" means that the content of the input file will also be
     expanded using pre-defined as well as user-defined placeholders, and
     optionally, environment variables. Then it will be saved to a temporary
     file, which will be used as an input for the sub-sequent external command
     execution. All temporary files will be deleted on the go. If no external
     command defined, then this will be interpreted as a simple expansion of the
     input. However, in order to achieve that, the "{exp-inp}" flag is
     still required to be set to true.

2.4. For the sake of source code portability, the environment variables are
     required to be specified strictly in UNIX/Linux/macOS format:
     \$ABC_123_DEF4 or \${ABC_123_DEF4} (under Windows though, environment
     variables will be considered case-insensitive). You can escape expansion
     by doubling the dollar sign: \$\$ABC.

2.5. To support \'expand-input\' feature, the program creates a temporary file
     where all placeholders get expanded. This file is located in the same
     directory where the current output file is supposed to be as well as
     with the same name, but the extension is replaced with .tmp.<input-ext>.
     For instance, if assets/images/custom.svg is converted to
     android/app/src/main/res/drawable-xhdpi/ic_launcher_background.png, then
     the temporary file path will be 
     android/app/src/main/res/drawable-xhdpi/ic_launcher_background.tmp.svg

2.6. For the sake of source code portability, the environment variables are
     required to be specified strictly in UNIX/Linux/macOS format:
     \$ABC_123_DEF4 or \${ABC_123_DEF4} (under Windows though, environment
     variables will be considered case-insensitive). You can escape expansion
     by doubling the dollar sign: \$\$ABC.

2.7. Directory separator char in file paths is also required to be specified in
     UNIX/Linux/macOS style: "abc/def/xyz.svg". For the sake of code portability
     it is also recommended (but not enforced) to avoid specifying DOS/Windows
     drive explicitly even if you run the program solely under those OSes.

2.8. The sub-node "action" should define an array of associative arrays with the
     rest of missing information (please note that the next array overwrites
     whatever was defined before, thus only the last command is the actual one;
     on the other hand, you could switch it to another one later like in a sort
     of a batch):

2.9. The line with the empty key is totally unnecessary, as such keys will be
     ignored. However, it allows to end all previous lines with the comma, which
     is handy enough to utilise this approach.

2.10.As you can see, any parameter can be changed at any time affecting sub-
     sequent data. 

2.11.The given sample file is the one I used to produce multiple launcher icons
     for a flutter app. Interestingly enough, it is forward-compatible with
     possible new types of project, and a typical example of that would be the
     addition of the last two data lines for web app generation.

##### Configuration file format (see full sample file below)

{
  "x": {
    "rename": {
      "{cmd}": "{c}",
      "{cur-dir}": "{CD}",
      "{exp-inp}": "{EI}",
      "{inp}": "{i}",
      "{out}": "{o}"
    },
    "action": [
      // Normal JS-like comments are allowed and will be removed on-the-fly before parsing data
      { "{EI}": true },

      // Terribly slow,
      //{ "{c}": "firefox --headless --default-background-color=0 --window-size={d},{d} --screenshot=\"{o}\" \"file://{i}\"" },

      // Sometimes fails to display svg properly,
      //{ "{c}": "wkhtmltoimage --format png \"{i}\" \"{o}\"" },

      // Not the best quality
      //{ "{c}": "convert \"{i}\" \"{o}\"" },

      // Not the best quality
      //{ "{c}": "inkscape -z -e \"{o}\" -w {d} -h {d} \"{i}\"" },

      // The most accurate
      { "{c}": "chrome --headless --default-background-color=0 --window-size={d},{d} --screenshot=\"{o}\" \"file://{i}\"" },

      { "{CD}": "flutter_app", "{img-src-dir}": "{CD}/assets/images" },

      { "{i}": "{img-src-dir}/app_bg.svg" },

      { "{w}":  48, "{h}":  48, "{o}": "android/app/src/main/res/drawable-mdpi/ic_launcher_background.png" },
      { "{w}":  72, "{h}":  72, "{o}": "android/app/src/main/res/drawable-hdpi/ic_launcher_background.png" },
      { "{w}":  96, "{h}":  96, "{o}": "android/app/src/main/res/drawable-xhdpi/ic_launcher_background.png" },
      { "{w}": 144, "{h}": 144, "{o}": "android/app/src/main/res/drawable-xxhdpi/ic_launcher_background.png" },
      { "{w}": 192, "{h}": 192, "{o}": "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_background.png" },

      { "{i}": "{img-src-dir}/app_fg.svg" },

      { "{w}":  48, "{h}":  48, "{o}": "android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png" },
      { "{w}":  72, "{h}":  72, "{o}": "android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png" },
      { "{w}":  96, "{h}":  96, "{o}": "android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png" },
      { "{w}": 144, "{h}": 144, "{o}": "android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png" },
      { "{w}": 192, "{h}": 192, "{o}": "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png" },

      { "{i}": "{img-src-dir}/app.svg" },

      { "{w}":  48,  "{h}": 48, "{o}": "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" },
      { "{w}":  72, "{h}":  72, "{o}": "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" },
      { "{w}":  96, "{h}":  96, "{o}": "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" },
      { "{w}": 144, "{h}": 144, "{o}": "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" },
      { "{w}": 192, "{h}": 192, "{o}": "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" },

      { "{w}": 1024, "{h}": 1024, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" },
      { "{w}": 20, "{h}": 20, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png" },
      { "{w}": 40, "{h}": 40, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png" },
      { "{w}": 60, "{h}": 60, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png" },
      { "{w}": 29, "{h}": 29, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png" },
      { "{w}": 58, "{h}": 58, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png" },
      { "{w}": 87, "{h}": 87, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png" },
      { "{w}": 40, "{h}": 40, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png" },
      { "{w}": 80, "{h}": 80, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png" },
      { "{w}": 120, "{h}": 120, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png" },
      { "{w}": 50, "{h}": 50, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png" },
      { "{w}": 100, "{h}": 100, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png" },
      { "{w}": 57, "{h}": 57, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png" },
      { "{w}": 114, "{h}": 114, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png" },
      { "{w}": 120, "{h}": 120, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png" },
      { "{w}": 180, "{h}": 180, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png" },
      { "{w}": 72, "{h}": 72, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png" },
      { "{w}": 144, "{h}": 144, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png" },
      { "{w}": 76, "{h}": 76, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png" },
      { "{w}": 152, "{h}": 152, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png" },
      { "{w}": 167, "{h}": 167, "{o}": "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png" },

      { "{w}": 192, "{h}": 192, "{o}": "web/icons/Icon-192.png" },
      { "{w}": 512, "{h}": 512, "{o}": "web/icons/Icon-512.png" },

      { "": null }
    ]
  }
}
''');
    }

    throw Exception(error);
  }
}
