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

Task28 adds the reviewed **linux/amd64** libvips8.18.7 package. Compile invokes
`script/native/vips/install.py` from the application, which downloads the exact
public release asset defined there, validates its SHA256, manifest/file hashes,
loaders and dynamic linkage, and atomically installs `vendor/rust-vips`. The installer
refuses other architectures and an existing prefix. The asset must be published
and independently checked before deploying; source code alone is not activation.
See `script/native/vips/README.md` for the immutable artifact identity.

`bin/web`, `bin/worker` and `bin/release` route Rust through `bin/rust`. That shared
wrapper selects the private prefix before the application and defaults Postgres
to TLS. Operator Rust commands must also use `bin/rust`. It refuses a missing or
wrong-version native package before starting the app. Rails commands keep their
existing runtime selection. The later legacy vips buildpack keeps its own `vendor/vips` prefix and profile
for Rails. It must not write `vendor/rust-vips`; the focused coexistence
control executes its retained compile after our installer and then sources its
profile before proving final Rust activation and linkage. Removing that provider
is outside this change.
