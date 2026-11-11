#!/bin/bash
# Exercise the classic buildpack contract with local stand-ins; no downloads or app access.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
# Apt supplies the compiler, builtin headers and libclang used by bindgen.
grep -qx 'clang-18' "$here/../../Aptfile"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
build="$work/build"
cache="$work/cache"
stubs="$work/stubs"
mkdir -p "$build/script/native/libxml2" "$build/db/seeds/orientations" "$build/db/rust" "$build/db/migrate" "$build/public/avo-assets" "$build/licenses/avo" "$cache/heroku-24/x86_64-unknown-linux-gnu/cargo/bin" "$stubs"
printf '[workspace]\n' > "$build/Cargo.toml"
printf 'lock\n' > "$build/Cargo.lock"
printf 'channel = "1.93.1"\n' > "$build/rust-toolchain.toml"
printf '[]\n' > "$build/script/native/libxml2/sources.json"
for source in db/seeds/orientations/2026.yml db/rust/20261104000000_job_queue.sql public/404.html public/422.html public/500.html NOTICE-avo.md; do
  printf 'synthetic\n' > "$build/$source"
done
printf 'export PKG_CONFIG_PATH=/synthetic\n' > "$build/script/native/libxml2/env.sh"
: > "$build/script/native/libxml2/fetch.py"
: > "$build/script/native/libxml2/build.sh"
cat > "$stubs/uname" <<'END'
#!/bin/sh
if [ "$1" = -s ]; then echo Linux; else echo x86_64; fi
END
cat > "$stubs/pkg-config" <<'END'
#!/bin/sh
echo 2.13.9
END
cat > "$stubs/curl" <<'END'
#!/bin/sh
echo 'unexpected download' >&2
exit 99
END
cat > "$stubs/python3" <<'END'
#!/bin/sh
printf 'python3 %s\n' "$*" >> "$CALLS"
exit 0
END
cat > "$stubs/bash" <<'END'
#!/bin/sh
exit 0
END
cat > "$stubs/sha256sum" <<'END'
#!/bin/sh
exit 99
END
for tool in patch make cc; do
  printf '#!/bin/sh\nexit 0\n' > "$stubs/$tool"
done
cat > "$stubs/install" <<'END'
#!/bin/sh
[ "$1" = -Dm755 ] || exit 99
mkdir -p "$(dirname "$3")"
cp "$2" "$3"
chmod 755 "$3"
END
cat > "$cache/heroku-24/x86_64-unknown-linux-gnu/cargo/bin/rustup" <<'END'
#!/bin/sh
printf 'rustup %s\n' "$*" >> "$CALLS"
END
cat > "$cache/heroku-24/x86_64-unknown-linux-gnu/cargo/bin/cargo" <<'END'
#!/bin/sh
printf 'cargo %s\n' "$*" >> "$CALLS"
mkdir -p "$CARGO_TARGET_DIR/release/examples"
printf '#!/bin/sh\nexit 0\n' > "$CARGO_TARGET_DIR/release/fc-register"
printf '#!/bin/sh\nexit 0\n' > "$CARGO_TARGET_DIR/release/examples/fc-load-probe"
END
chmod +x "$stubs"/* "$cache/heroku-24/x86_64-unknown-linux-gnu/cargo/bin"/*
export PATH="$stubs:$PATH" CALLS="$work/calls"
"$here/bin/detect" "$build" > "$work/detect"
grep -q 'fc-register Rust' "$work/detect"
if "$here/bin/detect" "$work" > /dev/null; then echo 'detect accepted a non-app' >&2; exit 1; fi
if STACK=heroku-22 /bin/bash "$here/bin/compile" "$build" "$cache" "$work/env" > "$work/stack.log" 2>&1; then
  echo 'unsupported stack accepted' >&2; exit 1
fi
grep -q 'unsupported STACK' "$work/stack.log"
STACK=heroku-24 /bin/bash "$here/bin/compile" "$build" "$cache" "$work/env" > "$work/compile.log" 2>&1
[[ -x $build/target/release/fc-register ]]
grep -q 'rustup toolchain install 1.93.1 --profile minimal' "$CALLS"
grep -q 'cargo build --release --locked -p web --bin fc-register' "$CALLS"
grep -Fq "python3 script/native/vips/install.py $build" "$CALLS"
[[ ! -e $build/target/release/fc-load-probe ]]
mkdir -p "$work/env"
printf 'synthetic-task26' > "$work/env/FC_BUILD_LOAD_PROBE"
STACK=heroku-24 /bin/bash "$here/bin/compile" "$build" "$cache" "$work/env" > "$work/probe.log" 2>&1
[[ -x $build/target/release/fc-load-probe ]]
grep -q 'cargo build --release --locked -p web --example fc-load-probe' "$CALLS"
printf 'arbitrary' > "$work/env/FC_BUILD_LOAD_PROBE"
if STACK=heroku-24 /bin/bash "$here/bin/compile" "$build" "$cache" "$work/env" > "$work/refuse-probe.log" 2>&1; then
  echo 'invalid probe opt-in accepted' >&2; exit 1
fi
rm "$work/env/FC_BUILD_LOAD_PROBE"
rm "$cache/heroku-24/x86_64-unknown-linux-gnu/cargo/bin/rustup"
: > "$CALLS"
if STACK=heroku-24 /bin/bash "$here/bin/compile" "$build" "$cache" "$work/env" > "$work/download.log" 2>&1; then
  echo 'failed rustup download was accepted' >&2; exit 1
fi
grep -q 'unexpected download' "$work/download.log"
[[ ! -s $CALLS ]]
echo 'owned buildpack: detect, stack refusal, pinned/locked compile, binary placement and download refusal passed'
