## doul

**Copyright © Alexander Iurovetski 2020 - 2021**

Command-line utility to run multiple commands against the same input with various parameters, and optionally, to expand placeholders inside the input

##### USAGE:

```
-h, --help                   this help screen
-q, --quiet                  quiet mode (no output, same as verbosity 0)
-v, --verbosity=<LEVEL>      how much information to show: 0-5, or: quiet, errors, normal, warnings, info, debug
                             (defaults to "normal")
-x, --xargs                  treat each plain argument independently (e.g. can pass multiple filenames as arguments)
-c, --config=<FILE>          configuration file in json format
-l, --list-only              display all commands, but do not execute those; if no command specified, then show config
-s, --append-sep             append record separator "," when filtering input config file (for "list-only" exclusively)
-f, --force                  ignore timestamps and force conversion
-d, --dir=<DIR>              startup directory
                             (defaults to ".")
-p, --compression=<LEVEL>    compression level for archiving-related operations (1..9) excepting BZip2
                             (defaults to "6")
    --print                  just print the arguments to stdout
    --copy                   just copy file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)
    --copy-newer             just copy more recently updated file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)
    --move                   just move file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)
    --move-newer             just move more recently updated file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)
    --rename                 just the same as --move
    --rename-newer           just the same as --move-newer
    --mkdir                  just create directories passed as plain arguments
    --delete                 just delete file(s) and/or directorie(s) passed as plain argument(s) (glob patterns allowed)
    --remove                 just the same as --delete
    --bz2                    just compress a single source file to a single destination BZip2 file, can be used with --move
    --unbz2                  just decompress a single BZip2 file to a single destination file, can be used with --move
    --gz                     just compress a single source file to a single GZip file, can be used with --move
    --ungz                   just decompress a single GZip file to a single destination file, can be used with --move
    --tar                    just create a single destination archive file containing source files and/or directories, can be used with --move
    --untar                  just untar a single archive file to a destination directory, can be used with --move
    --tbz                    just a combination of --tar and --bz2, can be used with --move
    --untbz                  just a combination of --untar and --unbz2, can be used with --move
    --tgz                    just a combination of --tar and --gz, can be used with --move
    --untgz                  just a combination of --untar and --ungz, can be used with --move
    --tzl                    just a combination of --tar and --zlib, can be used with --move
    --untzl                  just a combination of --untar and --unzlib, can be used with --move
    --zip                    just zip source files and/or directories to a single destination archive file, can be used with with --move to delete source to delete source
    --unzip                  just unzip single archive file to destination directory, can be used with with --move to delete source to delete source
    --zlib                   just compress a single source file to a single ZLib file, can be used with with --move to delete source to delete source
    --unzlib                 just decompress a single ZLib file to a single destination file, can be used with with --move to delete source to delete source
    --pack                   just compress source files and/or directories to a single destination archive file depending on its extension, can be used with --move
    --unpack                 just decompress a single source archive file to destination files and/or directories depending on source extension, can be used with --move
```

##### DETAILS:

##### More about command-line options

1.1. Ability to specify top directory as an option comes very handy if you (or
     your team) use(s) different OSes with a single version control repository.
     The noted approach allows to escape the need to specify OS-dependent paths
     in versioned files. You can run the program from specific location or put
     it as an option while running from a batch script, console, or by double-
     clicking a launcher (shortcut) icon. You can specify pathname separators
     in any style (forward slashes as in Unix or backslashes as in Windows),
     the program will expand those depending on the OS it is run under. This
     applies to {{-cur-dir-}}, {{-inp-}}, {{-out-}} as well as any other key,
     which matches the regular expression pattern in {{-detect-paths-}}. This
     does not apply to {{-cmd-}} by default, as the forward slashes might
     represent command-line option character(s) under Windows.

1.2. If the path to config file (option -c, --config) is not absolute, then its
     absolute path will be resolved using either program startup directory, or
     top directory (option -d, --dir) depending on which option is specified
     first. Yes, this is non-standard, as all options should not depend on the
     order of appearance, but in this case it becomes very handy. Anyway, you
     can avoid the ambiguity by specifying config file using absolute path.

1.3. The program also allows you to pass configration by piping some other
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
it doesn\'t care about specific placeholders and is capable of replacing
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
     self-descriptive, except "expand-content", which means that the content of
     the input file will also be expanded using pre-defined as well as user-
     defined placeholders, and optionally, environment variables. Then it will
     be saved to a temporary file, which will be used as an input for the sub-
     sequent external command execution. All temporary files will be deleted on
     the go. If no external command defined, then this will be interpreted as a
     simple expansion of the input. However, in order to achieve that, the
     "expand-content" flag is still required to be set to true.

2.4. For the sake of source code portability, the environment variables are
     required to be specified strictly in UNIX/Linux/macOS format:
     \$ABC_123_DEF4 or \${ABC_123_DEF4} (under Windows though, environment
     variables will be considered case-insensitive). You can escape expansion
     by doubling the dollar sign: \$\$ABC.

2.5. To support "expand-content" feature, the program creates a temporary file
     where all placeholders get expanded. This file is located in the same
     directory where the current output file is supposed to be as well as
     with the same name, but the extension is replaced with .tmp.<input-ext>.
     For instance, if assets/images/custom.svg is converted to
     android/app/src/main/res/drawable-xhdpi/ic_launcher_background.png, then
     the temporary file path will be 
     android/app/src/main/res/drawable-xhdpi/ic_launcher_background.tmp.svg

2.6. Environment variables as well as optionless arguments passed to doul, are
     expanded, but in configuration file only. If you\'d like to expand those
     in input file(s), simply assign that to some placeholder, then use that
     placehloder. For the sake of source code portability, the environment
     variables are required strictly in UNIX/Linux/macOS form: $\*, $@, $1,
     $2, ..., $ABC_123_DEF4 or ${\*}, ${@}, ${1}, ${2}, ..., ${ABC_123_DEF4}
     (under Windows though, environment variables will be considered case-
     insensitive). You can escape expansion by escaping with \ or doubling
     the dollar sign: \$ABC or $$ABC. In the former case nothing will change,
     but in the latter case, it will be replaced with a single dollar sign.
     Special placeholder $\* or $@ or ${\*} or ${@} is used to indicate an
     array of all optionless arguments, so the whole process will be repeated
     for each such argument. 

2.7. Directory separator char in file paths is also required to be specified in
     UNIX/Linux/macOS style: "abc/def/xyz.svg". For the sake of code portability,
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

##### Full sample configuration file to generate mobile (Flutter) app icons

See the details of the imported file `cmd.json` beyond this configuration

```
{
  // Normal JS-like comments are allowed and will be removed on-the-fly before parsing data

  "{{-rename-keywords-}}": {
    "{{-cmd-}}": "{c}",
    "{{-cur-dir-}}": "{cur-dir}",
    "{{-can-expand-content-}}": "{can-expand-content}",
    "{{-inp-}}": "{i}",
    "{{-out-}}": "{o}",
    "{{-next-}}": "{next}",
  },

  "{{-import-}}": "../cmd.json",

  "{can-expand-content}": true,

  // Terribly slow
  // { "{c}": "firefox --headless --default-background-color=0 --window-size={d},{d} --screenshot={o} \"file://{i}\"" },

  // Sometimes fails to display svg properly,
  // { "{c}": "wkhtmltoimage --format png \"{i}\" \"{o}\"" },

  // Not the best quality
  // { "{c}": "convert \"{i}\" \"{o}\"" },

  // Not the best quality
  // { "{c}": "inkscape -z -e \"{o}\" -w {d} -h {d} \"{i}\"" },

  // The most accurate. Do not enclose the output path in quotes, as this will not work, hence avoid spaces (existing bug in Chromium)
  "{c}": "{svg2png} --window-size={d},{d} --screenshot={o} \"file://{i}\"",

  "{img-src-dir}": "{cur-dir}/assets/images",

  "{i}": "{img-src-dir}/app{m}.svg",

  "{R}": [
    {
      "{suf}": [
        { "{m}": [ "_background", "_foreground" ], "{D}": "drawable" },
        { "{m}": "", "{D}": "mipmap" }
      ],

      "{dim}": [
        { "{d}":   48, "{r}": "m" },
        { "{d}":   72, "{r}": "h" },
        { "{d}":   96, "{r}": "xh" },
        { "{d}":  144, "{r}": "xxh" },
        { "{d}":  192, "{r}": "xxxh" }
      ],

      "{o}": "{cur-dir}/android/app/src/main/res/{D}-{r}dpi/ic_launcher{m}.png"
    },

    {
      "{{-drop-}}": "{suf}",

      "{dim}": [
        { "{d}": 1024, "{r}": 1024, "{k}": 1 },
        { "{d}":   20, "{r}":   20, "{k}": 1 },
        { "{d}":   40, "{r}":   20, "{k}": 2 },
        { "{d}":   60, "{r}":   20, "{k}": 3 },
        { "{d}":   29, "{r}":   29, "{k}": 1 },
        { "{d}":   58, "{r}":   29, "{k}": 2 },
        { "{d}":   87, "{r}":   29, "{k}": 3 },
        { "{d}":   40, "{r}":   40, "{k}": 1 },
        { "{d}":   80, "{r}":   40, "{k}": 2 },
        { "{d}":  120, "{r}":   40, "{k}": 3 },
        { "{d}":   50, "{r}":   50, "{k}": 1 },
        { "{d}":  100, "{r}":   50, "{k}": 2 },
        { "{d}":   57, "{r}":   57, "{k}": 1 },
        { "{d}":  114, "{r}":   57, "{k}": 2 },
        { "{d}":   60, "{r}":   60, "{k}": 1 },
        { "{d}":  120, "{r}":   60, "{k}": 2 },
        { "{d}":  180, "{r}":   60, "{k}": 3 },
        { "{d}":   72, "{r}":   72, "{k}": 1 },
        { "{d}":  144, "{r}":   72, "{k}": 2 },
        { "{d}":   76, "{r}":   76, "{k}": 1 },
        { "{d}":  152, "{r}":   76, "{k}": 2 },
        { "{d}":  167, "{r}": 83.5, "{k}": 2 }
      ],

      "{o}": "{cur-dir}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-{r}x{r}@{k}x.png"
    },

    {
      "{d}": [ 192, 512 ],
      "{o}":  "{cur-dir}/web/icons/Icon-{d}.png"
    }
  ]
}
```