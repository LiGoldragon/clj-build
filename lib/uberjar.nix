# The deployable form: one jar holding the sources and every dependency.
#   runtime = "bb":  a Babashka uberjar (`bb uberjar`), run by bb.
#   runtime = "jvm": an AOT-compiled JVM uberjar, run by `java -jar`. `main`
#                    needs a -main; a generated gen-class launcher calls it.
{ common }:
pkgs:
{
  name,
  src,
  main,
  deps,
  bin ? name,
  paths ? [ "src" ],
  runtime ? "jvm",
  runtimeInputs ? [ ],
  wrapperArgs ? [ ],
  babashka ? pkgs.babashka-unwrapped,
  jdk ? pkgs.jdk_headless,
}:
let
  depsDrv = common.resolveDeps pkgs deps;
  rt = common.checkRuntime runtime;
  share = "$out/share/${name}";
  jar = "${share}/${name}.jar";
  launcherSource = pkgs.writeText "clj_build_launcher.clj" ''
    (ns clj-build.launcher
      (:require [${main}])
      (:gen-class))
    (defn -main [& args]
      (apply ${main}/-main args))
  '';
  build =
    if rt == "bb" then
      ''
        ${babashka}/bin/bb --classpath "$classpath" uberjar "${jar}" -m ${main}
      ''
    else
      ''
        mkdir -p launcher/clj_build classes staging
        cp ${launcherSource} launcher/clj_build/launcher.clj
        ${jdk}/bin/java -Dclojure.compiler.direct-linking=true \
          -cp "$classpath:launcher:classes" clojure.main \
          -e "(binding [*compile-path* \"classes\"] (compile (quote clj-build.launcher)))"
        (cd staging
          for j in $(echo "$jars" | tr ':' ' '); do ${jdk}/bin/jar xf "$j"; done
          rm -f META-INF/MANIFEST.MF META-INF/*.SF META-INF/*.RSA META-INF/*.DSA)
        # staging/ is a build-time directory: every copy into it is made
        # writable, since store sources and extracted jars arrive read-only.
        chmod -R u+w staging
        ${builtins.concatStringsSep "\n" (map (p: "cp -r --no-preserve=mode ${src}/${p}/. staging/") paths)}
        chmod -R u+w staging
        cp -r --no-preserve=mode classes/. staging/
        chmod -R u+w staging
        ${jdk}/bin/jar --create --file "${jar}" --main-class clj_build.launcher \
          --date 1980-01-01T00:00:02Z -C staging .
      '';
  launch =
    if rt == "bb" then
      ''makeWrapper ${babashka}/bin/bb "$out/bin/${bin}" --add-flags "${jar}"''
    else
      ''makeWrapper ${jdk}/bin/java "$out/bin/${bin}" --add-flags "-jar ${jar}"'';
  drv = pkgs.runCommand "${name}-uberjar"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = bin;
    passthru.deps = depsDrv;
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME" "${share}" "$out/bin"
    jars=$(${common.jarClasspath { deps = depsDrv; file = "classpath"; runtime = rt; }})
    classpath="${common.joinPaths "${src}" paths}''${jars:+:$jars}"
    ${build}
    ${launch} \
      ${pkgs.lib.optionalString (runtimeInputs != [ ]) "--prefix PATH : ${pkgs.lib.makeBinPath runtimeInputs}"} \
      ${pkgs.lib.escapeShellArgs wrapperArgs}
  '';
in
# `jar` is the built jar's real store path, taken from the final package, so a
# consuming derivation that interpolates it depends on this one and finds the
# file. (`placeholder "out"` would resolve to the consumer's own $out.)
drv.overrideAttrs (
  finalAttrs: previousAttrs: {
    passthru = (previousAttrs.passthru or { }) // {
      jar = "${finalAttrs.finalPackage}/share/${name}/${name}.jar";
    };
  }
)
