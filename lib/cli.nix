# A wrapped Babashka (default) or JVM Clojure command with pinned deps.
# Sources stay as source; `main` is the namespace whose -main runs.
{ common }:
pkgs:
{
  name,
  src,
  main,
  deps,
  bin ? name,
  paths ? [ "src" ],
  runtime ? "bb",
  runtimeInputs ? [ ],
  wrapperArgs ? [ ],
  babashka ? pkgs.babashka-unwrapped,
  jdk ? pkgs.jdk_headless,
}:
let
  depsDrv = common.resolveDeps pkgs deps;
  rt = common.checkRuntime runtime;
  share = "$out/share/${name}";
  launch =
    if rt == "bb" then
      ''makeWrapper ${babashka}/bin/bb "$out/bin/${bin}" --add-flags "--classpath $classpath -m ${main}"''
    else
      ''makeWrapper ${jdk}/bin/java "$out/bin/${bin}" --add-flags "-cp $classpath clojure.main -m ${main}"'';
in
pkgs.runCommand name
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = bin;
    passthru.deps = depsDrv;
  }
  ''
    ${common.installPaths { inherit src paths; dest = share; }}
    jars=$(${common.jarClasspath { deps = depsDrv; file = "classpath"; runtime = rt; }})
    classpath="${common.joinPaths share paths}''${jars:+:$jars}"
    mkdir -p "$out/bin"
    ${launch} \
      ${pkgs.lib.optionalString (runtimeInputs != [ ]) "--prefix PATH : ${pkgs.lib.makeBinPath runtimeInputs}"} \
      ${pkgs.lib.escapeShellArgs wrapperArgs}
  ''
