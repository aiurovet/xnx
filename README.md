## xnx v0.1.0

### Copyright © Alexander Iurovetski 2020 - 2021**

A command-line utility to eXpand text content by replacing placeholders with the actual data aNd to eXecute external utilities.

#### USAGE

```
xnx [OPTIONS]

-h, --help                   this help screen
-c, --app-config=<FILE>      xnx application configuration file in JSON5 format https://json5.org/,
                             defaults to default.xnxconfig in the directory where .xnx file is from
-x, --xnx=<FILE>             the actual JSON5 file to process, see https://json5.org/,
                             default extension: .xnx
-d, --dir=<DIR>              directory to start in
-i, --import-dir=<DIR>       default directory for .xnx files being imported into other .xnx files,
                             the application will define environment variable _XNX_IMPORT_DIR
-m, --escape=<MODE>          how to escape special characters before the expansion: quotes, xml, html (default: none),
                             the application will define environment variable _XNX_ESCAPE
-q, --quiet                  quiet mode (no output, same as verbosity 0),
                             the application will define environment variable _XNX_QUIET
-v, --verbose                Shows detailed log, the application will define environment variable _XNX_VERBOSE,
-e, --each                   treat each plain argument independently (e.g. can pass multiple filenames as arguments)
                             see also -x/--xargs
-a, --xargs                  similar to -e/--each, but reads arguments from stdin
                             useful in a pipe with a file path finding command
-l, --list-only              display all commands, but do not execute those; if no command specified, then show config,
                             the application will define environment variable _XNX_LIST_ONLY
-s, --append-sep             append record separator "," when filtering input config file (for "list-only" exclusively),
                             the application will define environment variable _XNX_APPEND_SEP
-f, --force                  ignore timestamps and force conversion,
                             the application will define environment variable _XNX_FORCE
-p, --compression=<LEVEL>    compression level for archiving-related operations (1..9) excepting BZip2,
                             the application will define environment variable _XNX_COMPRESSION
-W, --wait-always            always wait for a user to press <Enter> upon completion
-w, --wait-err               wait for a user to press <Enter> upon unsuccessful completion
    --find                   just find recursively all files and sub-directories matching the glob pattern
                             in a given or the current directory and print those to stdout
    --print                  just print the arguments to stdout
    --env                    just print all environment variables to stdout
    --pwd                    just print the current working directory to stdout
    --copy                   just copy file(s) and/or directorie(s) passed as plain argument(s),
                             glob patterns are allowed
    --copy-newer             just copy more recently updated file(s) and/or directorie(s) passed as plain argument(s),
                             glob patterns are allowed
    --move                   just move file(s) and/or directorie(s) passed as plain argument(s),
                             glob patterns are allowed
    --move-newer             just move more recently updated file(s) and/or directorie(s) passed as plain argument(s),
                             glob patterns are allowed
    --rename                 just the same as --move
    --rename-newer           just the same as --move-newer
    --mkdir                  just create directories passed as plain arguments
    --delete                 just delete file(s) and/or directorie(s) passed as plain argument(s),
                             glob patterns are allowed
    --remove                 just the same as --delete
    --bz2                    just compress a single source file to a single destination BZip2 file,
                             can be used with --move
    --unbz2                  just decompress a single BZip2 file to a single destination file,
                             can be used with --move
    --gz                     just compress a single source file to a single GZip file,
                             can be used with --move
    --ungz                   just decompress a single GZip file to a single destination file,
                             can be used with --move
    --tar                    just create a single destination archive file containing source files and/or
                             directories, can be used with --move
    --untar                  just untar a single archive file to a destination directory,
                             can be used with --move
    --tarbz2                 just a combination of --tar and --bz2,
                             can be used with --move
    --untarbz2               just a combination of --untar and --unbz2,
                             can be used with --move
    --targz                  just a combination of --tar and --gz,
                             can be used with --move
    --untargz                just a combination of --untar and --ungz,
                             can be used with --move
    --tarz                   just a combination of --tar and --Z,
                             can be used with --move
    --untarz                 just a combination of --untar and --unz,
                             can be used with --move
    --zip                    just zip source files and/or directories to a single destination
                             archive file, can be used with --move to delete the source
    --unzip                  just unzip single archive file to destination directory,
                             can be used with --move to delete the source
    --z                      just compress a single source file to a single Z file,
                             can be used with --move to delete the source
    --unz                    just decompress a single Z file to a single destination file,
                             can be used with --move to delete the source
    --pack                   just compress source files and/or directories to a single destination
                             archive file depending on its extension, can be used with --move
    --unpack                 just decompress a single source archive file to destination files and/or
                             directories depending on the source extension, can be used with --move

For more details, see README.md
```

#### DETAILS

##### More about command-line options

1.1. Ability to specify top directory as an option comes very handy if you (or
     your team) use(s) different OSes with a single version control repository.
     The noted approach allows to escape the need to specify OS-dependent paths
     in versioned files. You can run the program from specific location or put
     it as an option while running from a batch script, console, or by double-
     clicking a launcher (shortcut) icon. You can specify pathname separators
     in any style (forward slashes (POSIX) or backslashes (Windows),
     the program will expand those depending on the OS it is run under. This
     applies to {{-cur-dir-}}, {{-inp-}}, {{-out-}} as well as any other key,
     which matches the regular expression pattern in {{-detect-paths-}}. This
     does not apply to cmd by default, as the forward slashes might
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

     grep -Pi "..." confdir/my.xnx | xnx -c- -d projdir


1.4. Similarly, the program allows you to pass input by piping some other
     program\'s output. In this case, put a dash instead of a filename for
     input:

     { ... "{{-inp-}}": "-" ...  } 

1.5. The program also allows you to print the result of expansion to stdout
     rather than to file. In this case, put a dash instead of a filename for
     input (and you won't be able to configure any external command, but rather
     will be confined to the use of a mere pipe):

     { ... "{{-out-}}": "-" ... }

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
     required to be specified strictly in POSIX format:
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

2.6. Environment variables as well as optionless arguments passed to xnx, are
     expanded, but in configuration file only. If you\'d like to expand those
     in input file(s), simply assign that to some placeholder, then use that
     placehloder. For the sake of source code portability, the environment
     variables are required in the form of: $\*, $@, $~1,
     $~2, ..., $ABC_123_DEF4 or ${\*}, ${@}, ${~1}, ${~2}, ..., ${ABC_123_DEF4}
     (under Windows though, environment variables will be considered case-
     insensitive). You can escape expansion by escaping with \ or doubling
     the dollar sign: \$ABC or $$ABC. In the former case nothing will change,
     but in the latter case, it will be replaced with a single dollar sign.
     The special placeholders $\*, $@, ${\*} and ${@} are used to indicate
     an array of all optionless arguments, so the whole process will be repeated
     for each such argument. 

2.7. Directory separator char in file paths is also required to be specified in
     POSIX style: "abc/def/xyz.svg". For the sake of code portability,
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

See the details of the imported file `shell.xnx` beyond this configuration

```json5
{
  "{{-import-}}": "../shell.xnx",

  "{{-can-expand-content-}}": true,

  "{{-detect-paths-}}": "\\{[^\\{\\}]+\\-(dir|path|pthp)\\}",

  "{org-dim}": "750",

  "{{-cmd-}}": "{svg2png}",

  "{img-src-dir}": "{{-cur-dir-}}/_assets/images",

  "{{-inp-}}": "{img-src-dir}/app{m}.svg",

  "{solid-fill}": "#f5cba7",

  "{R}": [
    {
      "{suf}": [
        { "{m}": [ "_background", "_foreground" ], "{D}": "drawable", "{fill}": "none" },
        { "{m}": "_foreground", "{D}": "mipmap", "{fill}": "{solid-fill}" }
      ],

      "{dim-res-mul}": [
        { "{dim}":   48, "{res}": "m" },
        { "{dim}":   72, "{res}": "h" },
        { "{dim}":   96, "{res}": "xh" },
        { "{dim}":  144, "{res}": "xxh" },
        { "{dim}":  192, "{res}": "xxxh" }
      ],

      "{{-func-}}": {
        "{scale}": [ "=Div", "{dim}", "{org-dim}" ],
      },

      "{{-out-}}": "{{-cur-dir-}}/android/app/src/main/res/{D}-{res}dpi/ic_launcher{m}.png"
    },

    {
      "{suf}": null,

      "{m}": "_foreground",
      "{fill}": "{solid-fill}",

      "{dim-res-mul}": [
        { "{dim}": 1024, "{res}": 1024, "{mul}": 1 },
        { "{dim}":   20, "{res}":   20, "{mul}": 1 },
        { "{dim}":   40, "{res}":   20, "{mul}": 2 },
        { "{dim}":   60, "{res}":   20, "{mul}": 3 },
        { "{dim}":   29, "{res}":   29, "{mul}": 1 },
        { "{dim}":   58, "{res}":   29, "{mul}": 2 },
        { "{dim}":   87, "{res}":   29, "{mul}": 3 },
        { "{dim}":   40, "{res}":   40, "{mul}": 1 },
        { "{dim}":   80, "{res}":   40, "{mul}": 2 },
        { "{dim}":  120, "{res}":   40, "{mul}": 3 },
        { "{dim}":   50, "{res}":   50, "{mul}": 1 },
        { "{dim}":  100, "{res}":   50, "{mul}": 2 },
        { "{dim}":   57, "{res}":   57, "{mul}": 1 },
        { "{dim}":  114, "{res}":   57, "{mul}": 2 },
        { "{dim}":   60, "{res}":   60, "{mul}": 1 },
        { "{dim}":  120, "{res}":   60, "{mul}": 2 },
        { "{dim}":  180, "{res}":   60, "{mul}": 3 },
        { "{dim}":   72, "{res}":   72, "{mul}": 1 },
        { "{dim}":  144, "{res}":   72, "{mul}": 2 },
        { "{dim}":   76, "{res}":   76, "{mul}": 1 },
        { "{dim}":  152, "{res}":   76, "{mul}": 2 },
        { "{dim}":  167, "{res}": 83.5, "{mul}": 2 }
      ],

      "{{-func-}}": {
        "{scale}": [ "=Div", "{dim}", "{org-dim}" ],
      },

      "{{-out-}}": "{{-cur-dir-}}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-{res}x{res}@{mul}x.png"
    },

    {
      "{m}": "_foreground",
      "{fill}": "{solid-fill}",

      "{dim-res-mul}": [
        { "{dim}": [ 16, 32, ],
          "{{-func-}}": { "{scale}": [ "=Div", "{dim}", "{org-dim}" ], },
          "{{-out-}}":  "{{-cur-dir-}}/web/icons/favicon-{dim}x{dim}.png" },
        { "{dim}": 180,
          "{{-func-}}": { "{scale}": [ "=Div", "{dim}", "{org-dim}" ], },
          "{{-out-}}":  "{{-cur-dir-}}/web/icons/apple-touch-icon.png" }
      ],
    },

    {
      "{m}": "_foreground",
      "{fill}": "{solid-fill}",

      "{dim}": 192,
      "{sub}": ['windows', 'linux', 'macos'],

      "{{-func-}}": { "{scale}": [ "=Div", "{dim}", "{org-dim}" ], },
      "{{-out-}}":  "{{-cur-dir-}}/{sub}/icon-{dim}x{dim}.png",
    },
  ]
}
```
