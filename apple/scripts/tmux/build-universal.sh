#!/bin/zsh
# Universal tmux runtime for the app bundle: builds each architecture with build-runtime.sh, then lipo merges
# the executables. The app is universal, so a single-architecture tmux would fail to run on the other kind of Mac.
set -euo pipefail

script_directory="${0:A:h}"
project_directory="${script_directory:h:h}"   # apple/
architectures=(arm64 x86_64)
universal_directory="$project_directory/.build/Tmux/universal/runtime"

# Each architecture build is cached by build-runtime.sh's fingerprint, so this is cheap when nothing changed.
runtimes=()
for architecture in $architectures; do
    runtimes+=("$(zsh "$script_directory/build-runtime.sh" "$architecture" | tail -n 1)")
done

# The universal runtime is only up to date if it was merged from exactly these per-architecture builds:
# after a version bump in versions.sh the per-architecture fingerprints change and this merges again.
universal_fingerprint="$(for runtime in $runtimes; do cat "$runtime/build-fingerprint"; done | shasum -a 256 | awk '{print $1}')"
if [[ -f "$universal_directory/build-fingerprint" ]] \
    && [[ "$(cat "$universal_directory/build-fingerprint")" == "$universal_fingerprint" ]] \
    && [[ -x "$universal_directory/bin/tmux" ]]; then
    print "$universal_directory"
    exit 0
fi

rm -rf "$universal_directory"
mkdir -p "${universal_directory:h}"
# terminfo, licenses and versions are architecture-independent: take them from the first build.
cp -R "$runtimes[1]" "$universal_directory"
executables=()
for runtime in $runtimes; do executables+=("$runtime/bin/tmux"); done
/usr/bin/lipo -create "${executables[@]}" -output "$universal_directory/bin/tmux"
python3 "$script_directory/verify-runtime.py" "$universal_directory" --architectures "${(j:,:)architectures}"
print -r -- "$universal_fingerprint" > "$universal_directory/build-fingerprint"
print "$universal_directory"
