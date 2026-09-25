# Shared shell fragments. Classpaths are assembled at build time from the
# deps derivation's line files, never at evaluation time.
rec {
  # Accept either a fetchCljDeps spec or an already-built deps derivation.
  resolveDeps = pkgs: deps: if deps ? outPath then deps else import ./fetch-deps.nix pkgs deps;

  # Jars that Babashka carries built in and must not load from the classpath.
  bbExcluded = "^org/clojure/(clojure|spec\\.alpha|core\\.specs\\.alpha)/";

  # Shell: print the jar classpath of `file` ("classpath" or
  # "classpath-aliases"), optionally dropping Babashka's built-ins.
  jarClasspath =
    { deps, file, runtime }:
    ''
      sed -E ${if runtime == "bb" then "'\\#${bbExcluded}#d'" else "''"} ${deps}/${file} \
        | sed "s|^|${deps}/repository/|" | paste -sd: -
    '';

  # Shell: copy each source path of `src` under `dest`, print them joined.
  installPaths =
    { src, paths, dest }:
    ''
      mkdir -p ${dest}
      ${builtins.concatStringsSep "\n" (map (p: "cp -r ${src}/${p} ${dest}/${p}") paths)}
    '';
  joinPaths = dest: paths: builtins.concatStringsSep ":" (map (p: "${dest}/${p}") paths);

  runtimes = [ "bb" "jvm" ];
  checkRuntime =
    runtime:
    if builtins.elem runtime runtimes then
      runtime
    else
      throw "clj-build: runtime must be one of ${builtins.toString runtimes}, got ${runtime}";
}
