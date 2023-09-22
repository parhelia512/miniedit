## Mini Edit 

MiniEdit is an open source desktop application for editing files like PHP, HTML, CSS, Python, D, C and Pascal using UTF8 encoding.
Also it can compile or run script of this files, if your already installed its compilers in your system, without need to open a project for it, 
if you are editing multiple files, e.g. Python, PHP it can run this files into console(cmd) or terminal(xterm).

### Target

 * Simple (beginners or kids)
 * Portable
 * Fast

![image](https://user-images.githubusercontent.com/287490/142615859-4b20ed44-ec27-4771-9fcd-eb437af33ad3.png)

### Features

 * Portable, one executable file, take it any where.
 * UTF8, Ansi, and UTF8, UC16LE, UC16BE encoding with BOM
 * Projects files, each project have special type/tendency (PHP, Lua, Python, Pascal, D)
 * Until now it is very Fast and very small
 * Search in files
 * Search for file
 * PHP XDebug
 * Tortoise SVN/GIT integrated in Windows, [TODO] RabbitVCS in Linux
 * [TODO] GDB debugging
 * Works in Windows and Linux
 * Compile and run Pascal, D, Go, Cpp (cpp todo not yet)
 * Run PHP, CMD, SH, BAT, Lua, Py
 * Themed colors can be customized easy

### Languages supported

 | Name       	| Methods     	| Engine     	|
 |--------------|--------------	|---------------|
 | PHP 			| run, debug 	| PHP 			|
 | Lua 			| run           | lua, luac, internal		|
 | Python 		| run           | python        |
 | Basic 		| run 			| SmallBasic, YaBasic|
 | Pascal 		| compile, run	| FPC           |
 | D 			| compile, run  | DMD           |
 | C 			| compile, run	|				|
 | Go 			| compile, run	| go			|
 | SL/OpenSim   | lint      	| LSL			|
 | CMD, Bat		| run			| cmd.exe		|
 | sh 			| run			| sh			|
 | csv 			| show			| 				|
 | btfont [TODO]| edit, show	| 				|

 
### Disadvantages
  
 * Not good in auto complete
 * Can't open unkown files
 * Can't open a huge file like logs
 * No external addons

### Contributing

Keep it as simple as possible.
There is an addons to add menu items to file or main menu tools.

### Build

MiniEdit is FreePascal/Lazarus project, to compile it you need to install all packages that needed

 * Use source code from github.com in branch "release", or use last tag,  branch "master" is my working upstream, it is not stable.
 * FreePascal FPC 3.3 or later
 * Lazarus last update from subversion repo, it is recommended, or use version 2.1
 * MiniLib https://github.com/parmaja/minilib
 * MiniCtrls https://github.com/parmaja/minictrls

Open each package in Lazarus and compile it in order.

#### Required Packages

    minilib\lib\MiniLib.lpk
    minilib\xml\source\MiniXML.lpk
    minilib\socket\source\MiniSockets.lpk
    minilib\connection\source\MiniConnections.lpk

    minictrls\src\MiniCtrls.lpk

#### Competitions

Notepad++ https://notepad-plus-plus.org/

Geany https://www.geany.org/

Textadept https://foicica.com/textadept/

CudaText https://cudatext.github.io/

PINote https://pinote.sourceforge.io/

Micro https://micro-editor.github.io/

mlsde https://sourceforge.net/projects/mlsde/
