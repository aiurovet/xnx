import 'dart:io';
import 'package:args/args.dart';

import 'config.dart';

class Help {
  static final Map<String, Object> OPT_HELP = {
    'name': 'help',
    'abbr': 'h',
    'help': 'this help screen',
    'negatable': false,
  };
  static final Map<String, Object> OPT_HELP_ALL = {
    'name': 'help-all',
    'abbr': 'H',
    'help': 'display detailed help, including config file format',
    'negatable': false,
  };
  static final Map<String, Object> OPT_TOPDIR = {
    'name': 'top-dir',
    'abbr': 'd',
    'help': 'top directory to resolve paths from (default: the current directory)',
    'valueHelp': 'DIR',
  };
  static final Map<String, Object> OPT_CONFIG = {
    'name': 'config',
    'abbr': 'c',
    'help': 'configuration file in json format (default: <DIR>${Platform.pathSeparator}${Config.DEF_FILE_NAME})',
    'valueHelp': 'FILE',
  };
  static final Map<String, Object> OPT_VERBOSE = {
    'name': 'verbose',
    'abbr': 'v',
    'help': 'display all output, including the one from running the external tool',
    'negatable': false,
  };

  static void printUsage(ArgParser parser, {bool isAll = false, String error = null}) {
    print('''

USAGE:

${Config.APP_NAME} [OPTIONS]

${parser.usage}
      ''');

    if (isAll) {
      print('''
DETAILS:

### More about command-line options

1.1. Ability to specify top folder as an option comes very handy if you (or
     your team) use(s) different OSes with a single version control repository.
     The noted approach allows to escape the need to specify OS-dependent paths
     in versioned files. You can run the program from specific location or put
     it as an option while running from a batch script, console, or by double-
     clicking a launcher (shortcut) icon. You can specify pathname separators
     in any style (forward slashes as in Unix or backslashes as in Windows),
     the progarm will replace all of those depending on the OS it is run under.
     Please note though,  

1.2. The program also allows you to pass configration by piping some other
     program's output. In this case, instead of supplying a filename (or path),
     just put a dash:

     grep -Pi "..." confdir/my.json | doul -c- -d projdir

1.3.  

### Configuration file format

Originally, this tool was written to produce multiple icon files in PNG format
from a single SVG source. The idea was that knowing width, height, input file
name and location of expected images (icons), it wouldn't be too hard to create
some config file, read all that information and run external command with all
required arguments. And in order to resize properly, the input file's width and
height had to be adjusted accordingly. However, the application is not really
bound to that particular task and can be used for different purposes. Generally,
it doesn't care about specific placeholders and is capable to expand anything.

Configuration file is expected in JSON format with the following guidelines:

2.1. The name of the top node name can be anything, it does not matter.
2.2. There should be two sub-nodes: associative array "rename" and an array
     of associative arrays "action".
2.3. The sub-node "rename" should define case-sensitive translations for the
     pre-defined placeholders:

   "rename": {
     "{command}": "{c}", "{expand-input}": "{E}", "{height}": "{h}",
     "{input}": "{i}", "{output}": "{o}", "{topDir}": "{TD}",
     "{width}": "{w}"
   },

   Here the key is a pre-defined placeholder, and the value is the translation.
   As you can see, this can make config file less verbose and easier to read.
   All pre-defined placeholders are self-descriptive, except "{expand-input}",
   which simply means that the content of the input file will also be expanded
   using these as well as user-defined placeholders, then saved to a temporary
   file used as an input for the subsequent external command execution 

4. The sub-node "action" should define an array of associative arrays with the
   rest of missing information (please note that the next array overwrites
   whatever was defined before, thus only the last command is the actual one;
   on the other hand, you could switch it to another one later like in a sort
   of a batch):

    "action": [
      { "{E}": true },

      { "{c}": "wkhtmltoimage --format png \"{i}\" \"{o}\" # fails to display svg properly" },
      { "{c}": "convert \"{i}\" \"{o}\" # not the best quality" },
      { "{c}": "inkscape -z -e \"{o}\" -w {w} -h {h} \"{i}\" # not the best quality" },
      { "{c}": "firefox --headless --default-background-color=0 --window-size={w},{h} --screenshot=\"{o}\" \"file://{i}\" # terribly slow" },
      { "{c}": "google-chrome --headless --default-background-color=0 --window-size={w},{h} --screenshot=\"{o}\" \"file://{i}\" # the most accurate" },

      { "{TD}": "./" },

      { "{i}": "assets/images/app_bg.svg" },

      { "{w}":  48, "{h}":  48, "{o}": "android/app/src/main/res/drawable-mdpi/ic_launcher_background.png" },
      { "{w}":  72, "{h}":  72, "{o}": "android/app/src/main/res/drawable-hdpi/ic_launcher_background.png" },
      { "{w}":  96, "{h}":  96, "{o}": "android/app/src/main/res/drawable-xhdpi/ic_launcher_background.png" },
      { "{w}": 144, "{h}": 144, "{o}": "android/app/src/main/res/drawable-xxhdpi/ic_launcher_background.png" },
      { "{w}": 192, "{h}": 192, "{o}": "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_background.png" },

      { "{i}": "assets/images/app_fg.svg" },

      { "{w}":  48, "{h}":  48, "{o}": "android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png" },
      { "{w}":  72, "{h}":  72, "{o}": "android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png" },
      { "{w}":  96, "{h}":  96, "{o}": "android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png" },
      { "{w}": 144, "{h}": 144, "{o}": "android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png" },
      { "{w}": 192, "{h}": 192, "{o}": "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png" },

      { "{i}": "assets/images/app.svg" },

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

    The last line is totally unnecessary (empty keys are ignored), but allows to
    end all previous lines with the comma, which is handy enough to keep it.

  5. The given example is the actually used one to produce multiple launcher
     icons for a flutter app. Interestingly enough, it is forward-compatible
     with possible new types of project, and a typical example is the addition
     of the last two lines of data for web app generation
''');
    }

    throw new Exception(error);
  }
}

class DEF_FILE_NAME {
}