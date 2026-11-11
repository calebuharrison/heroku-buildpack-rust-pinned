# fc-register Rust buildpack

This is an owned classic Heroku buildpack for `heroku-24`. Put it **after Apt**
and before buildpacks that produce Vite assets and the Rails slug. It is the
Rust buildpack; the previous emk buildpack must be removed. Detect requires the
application's Cargo manifest and pinned native source manifest. Compile builds
the SHA-256 checked, patched PIC static libxml2 2.13.9, installs the exact Rust
version from `rust-toolchain.toml` using an HTTPS and SHA-256 checked rustup
installer, and builds `--release --locked -p web --bin fc-register`. It writes
the executable to `target/release/fc-register` for `bin/web`, `bin/worker`, and
`bin/release`. It does not run migrations or connect to a database.

The preceding Apt stage must install `clang-18` from the application's `Aptfile`.
Its dependencies supply libclang and the compiler builtin headers. Bindgen finds
the versioned compiler through Apt's exported `PATH` and discovers its relocated
include paths; `libclang1-18` alone cannot provide those headers.

Rustup, Cargo registry and target files live in the app-local build cache,
partitioned by Heroku stack and Linux architecture. The binary and pinned
native prefix live in the slug. `rust-toolchain.toml`, `Cargo.lock`, and the
seven checksummed native artifacts are the version sources. Release `migrate`
uses `db/migrate` and `db/rust`; the slug also needs Vite assets, Rails public
error pages and `db/seeds/orientations/2026.yml`. The buildpack refuses other
stacks and platforms. Verify actual native command availability, linked parser,
TLS roots, seed branch and HTTP behavior on the scratch release; a successful
compile alone does not establish those runtime properties. In particular,
the signature renderer needs ImageMagick's literal `convert` command and its
Hurricane font. The heroku-24 base image supplies ImageMagick 6 `convert`,
but the actual scratch slug and signature output still require verification.
