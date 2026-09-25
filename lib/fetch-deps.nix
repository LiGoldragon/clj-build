# Resolves a deps.edn through the Clojure CLI inside a fixed-output
# derivation and keeps only the jars on the resolved classpaths, laid out
# as a Maven repository. Maven jars are byte-stable, so the hash is too.
#
# Output:
#   repository/<group>/<artifact>/<version>/<jar>
#   classpath           base classpath, one repository-relative jar per line
#   classpath-aliases   classpath with every alias in `aliases` applied
pkgs:
{
  edn,
  hash,
  aliases ? [ ],
  name ? "clj-deps",
}:
let
  aliasFlag = if aliases == [ ] then "" else "-A:" + builtins.concatStringsSep ":" aliases;
in
pkgs.stdenvNoCC.mkDerivation {
  inherit name;
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.clojure pkgs.git ];
  impureEnvVars = pkgs.lib.fetchers.proxyImpureEnvVars;
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = hash;
  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR/home" CLJ_CONFIG="$TMPDIR/clj-config" GITLIBS="$TMPDIR/gitlibs"
    mkdir -p "$HOME" "$CLJ_CONFIG" project
    m2="$TMPDIR/m2"
    cp ${edn} project/deps.edn
    cd project
    sdeps="{:mvn/local-repo \"$m2\"}"
    clojure -Sdeps "$sdeps" -Spath > "$TMPDIR/cp-base"
    clojure -Sdeps "$sdeps" -Spath ${aliasFlag} > "$TMPDIR/cp-aliases"
    cd ..
    mkdir -p "$out/repository"
    keep() {
      tr ':' '\n' < "$1" | while IFS= read -r entry; do
        case "$entry" in
          "$m2"/*.jar)
            relative="''${entry#"$m2"/}"
            install -Dm644 "$entry" "$out/repository/$relative"
            printf '%s\n' "$relative"
            ;;
        esac
      done
    }
    keep "$TMPDIR/cp-base" > "$out/classpath"
    keep "$TMPDIR/cp-aliases" > "$out/classpath-aliases"
    runHook postBuild
  '';
  dontInstall = true;
  dontFixup = true;
}
