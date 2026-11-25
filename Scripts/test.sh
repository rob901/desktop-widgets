#!/bin/zsh
# Runs the tests. With only the Command Line Tools installed (no Xcode),
# Swift Testing lives outside the default search paths, so point at it.
set -euo pipefail
cd "$(dirname "$0")/.."
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
if [[ -d $F/Testing.framework ]]; then
  swift test -Xswiftc -F -Xswiftc $F -Xlinker -F -Xlinker $F \
    -Xlinker -rpath -Xlinker $F -Xlinker -rpath -Xlinker $L "$@"
else
  swift test "$@"
fi
