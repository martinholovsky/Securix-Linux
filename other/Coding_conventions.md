Securix BASH coding conventions
===============================

First of all I really appreciate any contribution to Securix via Github, but because all of us have slightly different conventions when coding in BASH, please follow this guide.  
In that case code will stay clear and well readable even after years.

Make secure, well readable code, with focus on performance.


## Bash script template
Bash scripts should contain this header
```bash
#!/bin/bash

#: title: Script title
#: file: /file/path
#: desc: Description of script function
#: author: First and Last name
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
```

## Error Trap
Where possible please use error trap at the beginning of script.

```bash
# end script in case of error
# exception: if statement, until and while loop, logical AND (&&) or OR (||)
# trap also those exit signals: 1/HUP, 2/INT, 3/QUIT, 15/TERM, ERR

trap exit_on_error 1 2 3 15 ERR

exit_on_error() {
  local exit_status="${1:-$?}"
  echo -e "${txtred}»»» Exiting ${0} with status: ${exit_status} ${txtdefault}"
  exit "${exit_status}"
}
```

You can also source error trap from `/usr/sbin/securix-functions` definition.

```bash
# load securix functions
if [ ! -r "/usr/sbin/securix-functions" ]; then
    echo "--- PROBLEM: /usr/sbin/securix-functions doesnt exist!!"
    logger "CRITICAL: /usr/sbin/securix-functions doesnt exist!!"
    exit 1
else
    . /usr/sbin/securix-functions
fi
```

## Overview
- use 4 spaces Tab length
- One of the often used function is `f_msg` which colorize message based on its severity (info, warn, error), `$1` is level `$2` is text
- Cron scripts shouldn't use `f_msg` because output is forwarded to log and not to screen  
example: `f_msg error "Cant find XXX"` - will print "Cant find XXX" in red color
- Shared functions are defined in file `/usr/sbin/securix-functions`. Please be familiar with them so you don’t need to reinvent-the-wheel

Always properly test your code in all possible situations (does file/directory exist? what if variable is empty? ...) before contributing.

## Variables
- A variable name must be any sequence of characters not containing `:`, `#`, `=`, `-`, `%` or leading or trailing whitespace  
- Use only letters, numbers and underscores to avoid further issues  
- Variable names are case-sensitive
- Variable names "should" be lower-case (to avoid conflict with internal bash variables), but for readability we are not following that

Variables defined in `/etc/securix/securix.conf` starts with `SX_*` (SX_VARIABLE)

String variable must be enclosed in double-quotation mark, even if it is one word
```bash
VARIABLE="string"
```
Same for integer value
```bash
VARIABLE="123"
```

Same for execution (even for variable inside)
```bash
VARIABLE="$(echo "${MAILHOST}" | cut -d' ' -f3)"
```

Variable used inside quotation mark must be always enclosed by curly braces
```bash
echo "My name is ${USERNAME}"
```

When you're executing command inside script, do not use backquotes, but brackets
```bash
VAR="$(echo "${OUTPUT}" | awk '{ print $2 }')"
```
or
```bash
echo "$(date)" >> "${SECURIXLOG}"
```

**Every reference** to variable should be enclosed by double-quotation mark and curly braces

```bash
if [ "${VARIABLE}" -eq "0" ]; then
    echo "OK"
fi
```

**Just in this form the variable definition is unambiguous**

**Main reasons to follow this**
- variable could contain internal field separator and test will fail (e.g. `VARIABLE="aaa bbb"`).
- in case of variable or parameter expansion, case modification or work with fields and arrays you need to use curly braces anyway, so it's better to have convention everywhere the same  
e.g. `${VARIABLE}/foobar`, `${VARAIBLE##*/}`, `${VARIABLE^^}`, `${VARIABLE[0]}`

The only exception when you don't need to follow this is when it is expected that variable contain multiple values used as arguments, in `for` loops, etc.


## Arithmetic operations
For the readability you don't need to use curly braces
```bash
SIZE="$((PARTITION + 1000))"
#or
echo "$((a = 2 , b = 2 + a , a * b))"
#or
((count++))
#or
fill="$((((columns - colnumber) * chars) - 1))"
```
## IF statements
- Follow newlines, tabs and spaces
- All variables must be enclosed in double-quotation marks
- A newline is used after `then` and after `else`
- Compare integer values using one of `-eq, -ne, -lt, -le, -gt, -ge` meaning equal, not equal, less than, less than or equal, greater than, and greater than or equal.

```bash
if [ "${EUID}" -ne "0" ]; then
    f_msg error "This script must be run as root or via sudo"
    exit_on_error
else
    f_msg info "You have root permissions"
fi

# Check if variable is null
if [ -z "${VARIABLE}" ]; then
    f_msg info "Variable VARIABLE is null"
fi

# Compare string variable
if [ "${VARIABLE}" = "yes" ]; then
    f_msg info "Accepted"
fi

# Catch exit status
if [ "${?}" -eq "0" ]; then
    echo "Command end without problem"
fi

# [[ is used only for string pattern match

if [[ "${VARIABLE}" = "*Available*" ]]; then
    f_msg info "Variable start with \"A\""
fi
```

More information: [BASH if statements](http://www.linuxtutorialblog.com/post/tutorial-conditions-in-bash-scripting-if-statements)

## Loops
```bash
for arguments in "${@}"; do
    echo "${arguments}"
done
```
## Shell functions
Name of function must start with `f_*` so anyone can recognize it quickly.

Again please follow newlines, spaces, tabs, etc. convention

```bash
f_updatesecurix() {
    f_msg info "###-### Checking update of Securix scripts ---"
    f_download "${SECURIXUPDATE}/current"
    LASTVERSION="$(<current)"
    if [ "${SECURIXVERSION}" -eq "${LASTVERSION}" ]; then
        f_msg info "--- No updates available/needed"
    else
        f_msg info "--- New update available!"
    fi
}
```

## Case statement
We use mainly two forms

First one is optimized for readability
```bash
case "${HOSTTYPE}" in
    x86_64)
        ARCH="amd64"
        ;;
    i386|i486|i586|i686)
        ARCH="x86"
        ;;
    *)
    	echo "ERROR: valid architecture not found - ${HOSTTYPE}"
    	exit 1
    	;;
esac
```

And short-form mainly used in shared functions
```bash
case "${answer}" in
    y|Y|yes|YES|Yes) yesno="yes" ;;
    *) yesno="no" ;;
esac
```
## External commands
Try to avoid usage of external commands where it is not necessary (grep, awk, cut, cat, sed, ...).
Usally it is much faster to use built-in function, than executing external commands, especially if operation is performed upon variable (not file).


We don't need to use `VARIABLE="$(cat /path/to/file)"` when we want to set variable from file. Instead of this we can source file to variable directly.  
```bash
VARIABLE="$(</path/to/file)"
```

When we would like to get length of longest line in one file via `wc -L $file`, but it will produce output in format `$number $file`  

Usually we will do something like this:
```bash
wc -L "${file}" | awk '{ print $1 }' #bad example
```

But we can use parameter expansion to split value from filename
```bash
LONGLINE="$(wc -L "${file}")"
# longest match of the pattern " *" from the end of the string
LONGLINE="${LONGLINE%% *}"
```

If it will work for you, don't use `ls | grep`  
```bash
KERNEL="$(ls /usr/src/ | grep hardened)" #bad example
```
if you can, use globing (or for loop) instead
```bash
KERNEL="/usr/src/*hardened*"
```

## Parameter expansion

In most cases you don't need to even call `sed` command externally.  
Search and replace example:

```bash
MYVAR="abc 123 abc 456"

# one slash is to only substitute the first occurrence
echo "${MYVAR/abc/klm}" # will produce: klm 123 abc 456

# two slashes is to substitute all occurrences
echo "${MYVAR//abc/klm}" # will produce: klm 123 klm 456
```

When we would like to split path from file name, but without commands like `basename` or `dirname`  
```bash
FILE="/aaa/bbb/ccc.tgz"
FILEPATH="${FILE%/*}" # will produce /aaa/bbb
FILENAME="${FILE##*/}" # will produce ccc.tgz
FILEEXTENSION="${FILE##*.}" # will produce tgz
```

**Case modification**
- `^` operator modifies the first character to uppercase
- `,` operator to lowercase
- double-form (`^^` and `,,`) convert all characters.
- (currently undocumented) operators `~` and `~~` reverse the case of given text

```bash
MYVAR="aaBBcc"
echo "${MYVAR^}"  # AaBBcc
echo "${MYVAR^^}" # AABBCC
echo "${MYVAR,,}" # aabbcc
echo "${MYVAR~~}" # AAbbCC
```

More information here [http://wiki.bash-hackers.org/syntax/pe](http://wiki.bash-hackers.org/syntax/pe)

## this is the end...

To explore more, please read great site [wiki.bash-hackers.org](http://wiki.bash-hackers.org)  
For syntax check and code analysis use [ShellCheck website](http://www.shellcheck.net/)  

...and here are few code editors which we can recommend (open-source)  
[Atom #atom.io](https://atom.io/)  
[Lime Text #limetext.org](http://limetext.org/)  
[Komodo Edit #komodoide.com](http://komodoide.com/komodo-edit/)
