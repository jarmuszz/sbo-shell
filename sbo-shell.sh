# Source this file
# sbo-shell - Simple toolset for managing your SBo packages.

# This is free and unencumbered software released into the public domain.
# 
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
# 
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
# 
# For more information, please refer to <http://unlicense.org/>

# Config
# REPO=${REPO:-"~/repo"} # Set your repository directory here
ACCENT=${ACCENT:-31}
PROMPT=${PROMPT:-"(\e[${ACCENT}mSBo\e[0m) $PS1"}
SPLASH=${SPLASH:-yes}
# End of Config

# Constants
INFO_VARS="PRGNAM
VERSION
HOMEPAGE
DOWNLOAD
MD5SUM
DOWNLOAD_x86_64
MD5SUM_x86_64
REQUIRES
MAINTAINER
EMAIL"
# End of Constants

# Internal functions
#	 Those functions are supossed to be called only
#	 from other functions.
intern_color() { printf "\e[${ACCENT}m%s\e[0m" "$@"; }

## Expanding variables in printf's $1 may resoult in undefined
## behaviour but allows for passing escape sequences as arguments.
intern_warn()	 { printf "%s: ${1}\n" "$(intern_color WARNING)"; }
intern_info()	 { printf "%s: ${1}\n" "$(intern_color INFO)"; }
intern_sourced_infop()	{ [ -n "$INFO" ]; }

intern_print_infovar() {
	[ -n "$(eval printf '%s' \"\$$1\")" ] &&
		eval "echo \"${1}: $"${1}'"'
}

intern_map() {
	# $1 - function name, /dev/stdin list
	 while read -r var; do $1 $var; done
}

intern_tree() {
	# Called by _tree
	TREEDEPTH=${TREEDEPTH:-0}

	if [ "$TREEDEPTH" -eq "0" ]; then
		printf "%s\n" "$PRGNAM"
	else
		printf "%${TREEDEPTH}s%s\n" ' ' "$PRGNAM"
	fi

	[ -n "$REQUIRES" ] && {
		echo "$REQUIRES" | tr ' ' '\n' | while read -r PKG; do
			OLDCWD="$PWD"

			TREEDEPTH=$(( TREEDEPTH + 2 ))
			_source_info "$(_find $PKG)"
			intern_tree "$REQUIRES"

			cd "$OLDCWD"
			unset -v OLDCWD
		done
	}
}

intern_test() {
	:
}
# End of Internal functions

# User functions
#		Functions called by the user themself

## Building and Metainfo
_download_sources() {
	# Downloads sources from $DOWNLOAD{,_x86_64}

	intern_sourced_infop || {
		intern_warn "The .info file is not sourced.\nNothing happened." 
		return
	}

	ARCH="$(arch)"
	if [ "$ARCH" = "x86_64" ] && [ -n "$DOWNLOAD_x86_64" ]; then
		intern_info "Downloading for x86_64 architecture."
		# shellcheck disable=SC2086
		wget $DOWNLOAD_x86_64
	else
		intern_info "Downloading for NON-x86_64 architecture."
		# shellcheck disable=SC2086
		wget $DOWNLOAD
	fi
}

_info() {
	# Prints variables from sourced .info file.

	# Optional: $1 - Package to temporary source and print info
	[ -n "$1" ] && (
		_source_info "$1"
		_info
	) && return

	intern_sourced_infop || {
		intern_warn "The .info file is not sourced.\nNothing happened." 
		return
	}

	echo "$INFO_VARS" | while read -r VAR; do
		intern_print_infovar "$VAR"
	done
}

_pull() (
	# Does git pull and recreates package list

	cd "$REPO"
	git pull
	find  . -mindepth 2 -maxdepth 2 -name "*" | sed 's/^\.\///' > PKGLIST
)

_slackbuild() {
	# Runs slackbuild

	intern_sourced_infop || {
		intern_warn "The .info file is not sourced.\nNothing happened." 
		return
	}
	
	echo "sudo sh \"${PRGNAM}\".SlackBuild"
	sudo sh "${PRGNAM}".SlackBuild
}

_source_info() {
	# Sources .info file from current directory
	
	# Optional: $1 - Package to source
	if [ -n "$1" ]; then
		si_OLDCWD="${PWD}"

		_goto "$1"
		_source_info 

		cd "$si_OLDCWD"
		unset -v si_OLDCWD
		return
	fi

	if [ -e ./*.info ]; then
		_unset_info
		. ./*.info &&
			INFO=true
	else
		intern_warn "The info file could not be found.\nNothing happened."
	fi
}

_unset_info() {
	# Unsets all variables from the .info file

	# shellcheck disable=SC2046
	unset -v $(echo "$INFO_VARS" | tr '\n' ' ')
	INFO=""
}
## End of Building and Metainfo

## Searching and Movement
_changelog() (
	# Displays newest entry in the ChangeLog.txt for every installed
	#	SBo package.
	
	# Optional: $1 - Package which newest entry in ChangeLog.txt 
	#                will be displayed
	cd /var/lib/pkgtools/packages

	for file in ${1:-*_SBo}; do
		grep -n -m 1 "/$(echo $file | sed 's/-[0-9].*//'):" "$REPO/ChangeLog.txt"
	done | sort -n
)

_dependencies() {
	# Prints dependencies of package whose .info file was sourced.

	# Optional: $1 - Package whose dependencies will be printed
	[ -n "$1" ] && (
		_source_info "$1"
		printf '%s\n' "$REQUIRES"
	) && return

	intern_sourced_infop || {
		intern_warn "The .info file is not sourced.\nNothing happened." 
		return
	}

	printf '%s\n' "$REQUIRES"
}

_find() {
	# Searches for package in the repository tree.
	# $1 - Package to search

	if [ -z "$1" ]; then
		intern_warn "Find what?\nNothing happened."
		return
	fi
	cd "$REPO"
	set -f
	grep "^.*/${1}$" PKGLIST | sort | uniq
	set +f
}

_goto() {
	# Changes current directory to package's tree.
	# $1 - Package to go to (either 'package' or 'category/package')
	gt_OLDCWD="${PWD}"

	if [ -z "$1" ]; then
		intern_warn "Go to where?\nNothing happened."
		return
	fi
	if [ -d "$REPO/$1" ]; then
		cd "$REPO/$1"
	else
		cd "$REPO"/$(_find "$1")
	fi

	[ "$?" -gt "0" ] && {
		intern_warn "This package doesn't seem to exitst.\nNothing happened."
		cd "$gt_OLDCWD"
	}
	unset -v gt_OLDCWD
}

_repo() {
	# Changes cwd to $REPO
	cd "$REPO" && echo "$REPO"
}

_tree() {
	# Displays full dependency tree of the sourced package. 

	REQUIRES_DUP="$REQUIRES"

	# Optional: -f - Instead of printing a tree just print every
	#                needed dependency in a parsable way.
	[ "$1" = "-f" ] && {
		FLAT=1
		shift
	}

	# Optional: $1 | $2 - Package whose dependency tree will be printed.
	[ -n "$1" ] && {
		_source_info "$1"
		shift
	}

	intern_sourced_infop || {
		intern_warn "The .info file is not sourced.\nNothing happened." 
		return
	}

	if [ -n "$FLAT" ]; then
		shift
		intern_tree "$REQUIRES" | sort -u | sed 's/\s*//' | awk '!x[$0]++'
	else
		intern_tree "$REQUIRES"
	fi

	REQUIRES="$REQUIRES_DUP"
	unset -v REQUIRES_DUP FLAT
}

_version_cmp() (
	# For every installed SBo package, check if it's version
	# compared to the SBo repository tree, if it's out-of-date
	# then print the package name, local version and repo version.
	cd /var/lib/pkgtools/packages

	# Optional: $1 - Instead of checking every SBo package, check $1
	PKGS="$(echo ${1}*_SBo)"

	set -f
	for pkg_full in $PKGS; do
		[ -e "$pkg_full" ] || {
			intern_warn "Package \"$1\" does not exist.\nNothing happened."
			return
		}

		# Pkg name (e.g. xclip)
		PKG="${pkg_full%%-[0-9]*}"

    # Pkg name truncated right (e.g. xclip-0.13)
		TR="${pkg_full%-*-*}"

		# Pkg local version
		VERSION_LOCAL="${TR##*-}"

		# Sources $VERSION (Pkg's repository version)
		. "$REPO/$(_find $PKG)/${PKG}.info"

		[ "$VERSION_LOCAL" != "$VERSION" ] &&
			printf "%s: %s %s\n" "$PKG" "$VERSION_LOCAL" "$VERSION"
	done
	set +f
)
## End of Searching and Movement


## Miscellaneous
_help() {
	# Prints help

	cat <<EOF
sbo-shell 0.1 - Things not really tested

Building and Metainfo
_download_sources   - Downloads sources from the sourced .info file.
_info [PKG]         - Displays all variables set in the .info file. If PKG
                      was passed and it is a valid package name then print
                      it's .info file.
_pull               - Git-pulls repository and rebuilds the package list.
_slackbuild         - Builds slackbuild as a root.
_source_info [PKG]  - Sources the .info file from current directory. If PKG 
                      was passed and it is a valid package name then source
                      it's .info file.
_unset_info         - Unsets all variables sourced  from the .info files.

Searching and Movement
_changelog [PKG]    - Prints the newest entry in $REPO/ChangeLog.txt
                      either for every installed SBo package or for PKG if
                      it is a valid SBo package name.
_dependencies       - Prints dependencies from the sourced .info file.
_find PKG           - Searches for exact-match PKG in the repository.
_goto PKG           - Changes current directory to the designated package's
                      repo tree.
_repo               - Changes current directory to the SBo repo tree.
_tree [-f] [PKG]    - Prints dependency tree for package which .info file
                      is currently sourced. If PKG was passed and it is a 
                      valid package name then use it's .info file. If '-f'
                      was passed then prints "flatten" dependency tree.
_version_cmp [PKG]  - Prints every installed SBo out-of-date package. If 
                      PKG was passed then check only it.

Miscellaneous
_help               - Displays this message.
_end                - Ends sbo-shell.
EOF
}

_end() {
	# Ends the sbo-shell session, unsets all that has been set.

	PS1="$OLDPS1"

	# Variables
	unset -v OLDPS1 REPO INFO

	# From .info files
	_unset_info
	
	unset -f \
		intern_info \
		intern_warn \
		intern_sourced_infop \
		intern_color \
		intern_map \
		intern_print_infovar \
		intern_tree \
		intern_test \
		_download_sources \
		_info \
		_pull \
		_slackbuild \
		_source_info \
		_unset_info \
		_changelog \
		_dependencies \
		_find \
		_goto \
		_repo \
		_tree \
		_version_cmp \
		_help \
		_end \

}
## End of Miscellaneous

# End of User functions

# Setting PS1
OLDPS1="$PS1"
PS1="$PROMPT"
unset -v PROMPT 
# End of Setting PS1

# Checking whether the $REPO is set
if [ -z "$REPO" ]; then
	cat <<EOF >&2
You have to set the \$REPO variable.
sbo-shell did not start.
EOF
	_end
else
	[ "$SPLASH" = "no" ] ||
		printf "Welcome to sbo-shell, type $(intern_color _help) to see all available commands.\n"
fi
# End of Checking whether the $REPO is set
