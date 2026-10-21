#!/bin/zsh
# Universal tmux runtime for the app bundle: builds each architecture with build-runtime.sh, then lipo merges
# the executables. The app is universal, so a single-architecture tmux would fail to run on the other kind of Mac.
set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h:h}"   # apple/
architectures=(arm64 x86_64)
universal_directory="$project_directory/.build/Tmux/universal/runtime"

runtimes=()
for architecture in $architectures; do
    runtimes+=("$(zsh "$script_directory/build-runtime.sh" "$architecture" | tail -n 1)")
done

rm -rf "$universal_directory"
mkdir -p "${universal_directory:h}"
# terminfo, licenses and versions are architecture-independent: take them from the first build.
cp -R "$runtimes[1]" "$universal_directory"
rm -f "$universal_directory/build-fingerprint"
executables=()
for runtime in $runtimes; do executables+=("$runtime/bin/tmux"); done
/usr/bin/lipo -create "${executables[@]}" -output "$universal_directory/bin/tmux"
python3 "$script_directory/verify-runtime.py" "$universal_directory" --architectures "${(j:,:)architectures}"
print "$universal_directory"
