# Flake checks running a -clj tool's clojure.test namespaces offline.
# Returns { clj-tests = <derivation>; } to merge into a flake's `checks`.
# Fails on any failure or error, and when no test ran.
{ common }:
pkgs:
{
  src,
  tests,
  deps,
  name ? "clj",
  paths ? [ "src" "test" ],
  runtime ? "jvm",
  nativeBuildInputs ? [ ],
  preCheck ? "",
  babashka ? pkgs.babashka-unwrapped,
  jdk ? pkgs.jdk_headless,
}:
let
  depsDrv = common.resolveDeps pkgs deps;
  rt = common.checkRuntime runtime;
  namespaces = builtins.concatStringsSep " " tests;
  runner = pkgs.writeText "clj-build-test-runner.clj" ''
    (require 'clojure.test)
    (def namespaces '[${namespaces}])
    (apply require namespaces)
    (let [{:keys [test fail error]} (apply clojure.test/run-tests namespaces)]
      (System/exit (if (and (pos? test) (zero? (+ fail error))) 0 1)))
  '';
  run =
    if rt == "bb" then
      ''${babashka}/bin/bb --classpath "$classpath" ${runner}''
    else
      ''${jdk}/bin/java -cp "$classpath" clojure.main ${runner}'';
in
{
  clj-tests =
    pkgs.runCommand "${name}-tests"
      {
        inherit nativeBuildInputs;
        passthru.deps = depsDrv;
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        jars=$(${common.jarClasspath { deps = depsDrv; file = "classpath-aliases"; runtime = rt; }})
        classpath="${common.joinPaths "${src}" paths}''${jars:+:$jars}"
        cd "$TMPDIR"
        ${preCheck}
        ${run}
        touch "$out"
      '';
}
