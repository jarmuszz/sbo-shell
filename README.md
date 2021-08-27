sbo-shell - Simple tool-set for managing your SBo packages.
---

> **Not really tested, things may break, functions are expected to change**

Sbo-shell provides a set of POSIX shell functions that allows administrator
to manage local [SBo git repository
tree](https://git.slackbuilds.org/slackbuilds/) and SBo package
installations through the shell scripting.

## Usage
Point the $REPO variable in `sbo-shell.sh` file to your local SBo repository
and then, in your POSIX shell, source the said file and run a `_pull`
function to repull the repository and generate PKGLIST. All of the user
functions begin with a `_` so that they can be easily listed by tab
completion. There are also "internal" functions which are supposed to be
called only from other functions (but nothing is really stopping you from
using them), they all begin with `intern_`.

To end the `sbo-shell` use the `_end` function. **Important** - sourcing
the `sbo-shell.sh` file does **not** spawn a sub-shell, exiting the shell
(e.g. with `exit` command) will close the whole shell, not only the
`sbo-shell` session.

### User functions
#### Building and Metainfo
| Function | Parameters | Description |
--- | --- | ---
|_download_sources| | Downloads sources from the sourced .info file. |
|_info| [PKG] | Displays all variables set in the .info file. If PKG was passed and it is a valid package name then print it's .info file. |
|_pull| | Git-pulls repository and rebuilds the package list. |
|_slackbuild| | Builds slackbuild as a root. |
|_source_info| [PKG] | Sources the .info file from current directory. If PKG was passed and it is a valid package name then source it's .info file. |
|_unset_info| | Unsets all variables sourced  from the .info files. |

#### Searching and Movement
| Function | Parameters | Description |
--- | --- | ---
|_changelog| [PKG] | Prints the newest entry in $REPO/ChangeLog.txt either for every installed SBo package or for PKG if it is a valid SBo package name. |
|_dependencies| | Prints dependencies from the sourced .info file. |
|_find| PKG | Searches for exact-match PKG in the repository. |
|_goto| PKG | Changes current directory to the designated package's repo tree. |
|_repo| | Changes current directory to the SBo repo tree. |
|_tree| [-f] [PKG] | Prints dependency tree for package which .info file is currently sourced. If PKG was passed and it is a valid package name then use it's .info file. If '-f' was passed then prints "flatten" dependency tree. |
|_version_cmp| [PKG] | Prints every installed SBo out-of-date package. If PKG was passed then check only it. |

#### Miscellaneous
| Function | Description |
--- | ---
|_help | Displays help regarding these functions. |
|_end | Ends sbo-shell. |

## Examples
### Checking whether neovim is up-to-date
	_version_cmp neovim

### Checking whether every neovim dependency is up-to-date
	 _tree -f neovim | while read pkg; do _version_cmp $pkg; done
or using `intern_map`

	_tree -f neovim | intern_map _version_cmp

### **Dangerous** - Auto-installing neovim and all of it's dependencies
	_tree -f neovim | while read pkg; do
		_goto $pkg
		_source_info
		_slackbuild && {
			installpkg /tmp/$pkg*_SBo*.t?z
			rm /tmp/$pkg*_SBo*.t?z
		}
	done
Don't do the above, **always** review SlackBuilds and dependencies before
building and installing them <3.

## Reporting Bugs
All bugs, suggestions and other issues report to the github issue tracker.  
Made by Mariusz Jakoniuk aka Jarmusz (jarmuszz AT tuta DOT io).

## TODO
* [ ] Test all of the functions.
* [ ] Optimize functions (less recursion, less subshells, globbing when possible).
* [ ] Minimize calling of user functions from other user functions.
	+ [ ] Split `_find` and `_goto` into `intern_` and user functions.
	+ [ ] Rework some things.
* [ ] Support passing env variables into `_slackbuild`.
* [ ] Add reloading mechanism.
* [ ] Add a mechanism preventing running sbo-shell multiple times.
* [ ] Implement more functions.
	+ [ ] `_package_installed`
* [ ] Add better examples showing more functions.

## License
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/>
