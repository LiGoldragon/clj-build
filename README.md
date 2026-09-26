# clj-build

Shared Nix build library for LiGoldragon Clojure (`-clj`) tools, the Clojure
counterpart of `rust-build`. Every builder takes the consumer's `pkgs` first.

```nix
clj-build.lib.${system}.mkCljCli     pkgs { name, src, main, deps, bin ? name, runtime ? "bb" }
clj-build.lib.${system}.mkCljUberjar pkgs { name, src, main, deps, bin ? name, runtime ? "jvm" }
clj-build.lib.${system}.mkCljChecks  pkgs { src, tests, deps, runtime ? "jvm" }  # => { clj-tests = drv; }
clj-build.lib.${system}.fetchCljDeps pkgs { edn, hash, aliases ? [ ], name ? "clj-deps", clojureVersion ? "1.12.6" }
```

- `deps` is a `fetchCljDeps` spec (or its result): the `deps.edn` is resolved
  once in a fixed-output derivation; builds and checks then run offline.
  Start with `hash = lib.fakeHash` and take the reported hash.
  The hash does not depend on the consumer's Clojure CLI: a `deps.edn` that
  names no `org.clojure/clojure` resolves `clojureVersion`, not the CLI's own
  version; a `deps.edn` that names one keeps it.
- `main` is the namespace whose `-main` runs. `runtime` is `"bb"` (Babashka)
  or `"jvm"`. `paths` (default `[ "src" ]`, tests `[ "src" "test" ]`) are the
  source roots inside `src`.
- `mkCljCli` wraps sources and jars as a command; `mkCljUberjar` builds one
  jar (a `bb uberjar`, or an AOT JVM jar with a generated launcher).
  Both accept `runtimeInputs` and raw `wrapperArgs` (e.g. `--set` for a pod).
  An uberjar's `passthru.jar` is the jar's real store path; another
  derivation that interpolates it depends on the uberjar and finds the file.
- `mkCljChecks` runs the named `clojure.test` namespaces with the `aliases`
  classpath; it fails on any failure or error, and when no test ran.

`nix flake check` builds `example/` through every builder and runs it.
