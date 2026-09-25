# Builds the example CLI through every builder and runs it offline.
{ pkgs, clj }:
let
  deps = {
    name = "clj-build-example-deps";
    edn = ../example/deps.edn;
    hash = "sha256-HNlkGVUe61CxFetUQ/bJwGuhAPAaTEgvk1FCgdpZ1MU=";
    aliases = [ "test" ];
  };
  common = {
    name = "example";
    src = ../example;
    main = "example.main";
    inherit deps;
  };
  cliBb = clj.mkCljCli pkgs common;
  cliJvm = clj.mkCljCli pkgs (common // { runtime = "jvm"; bin = "example-jvm"; });
  jarJvm = clj.mkCljUberjar pkgs common;
  jarBb = clj.mkCljUberjar pkgs (common // { runtime = "bb"; bin = "example-bb-jar"; });
  runs =
    pkgs.runCommand "clj-build-example-runs" { } ''
      for command in ${cliBb}/bin/example ${cliJvm}/bin/example-jvm \
                     ${jarJvm}/bin/example ${jarBb}/bin/example-bb-jar; do
        "$command" '{:name "field"}' > ok
        grep -F '{:status :ok, :greeting "hello field"}' ok
        if "$command" '{:name ""}' > refused; then
          echo "$command accepted invalid input" >&2
          exit 1
        fi
        grep -F ':refused' refused
      done
      touch "$out"
    '';
  # A second derivation must reach each uberjar through `passthru.jar`.
  # Evaluation: the path lies inside the uberjar's own output and carries it
  # as string context (so a consumer depends on it); it is not a placeholder.
  jarPathOf =
    drv:
    let
      jar = drv.jar;
      prefix = "${drv}/share/";
      context = builtins.attrNames (builtins.getContext jar);
    in
    assert pkgs.lib.assertMsg (pkgs.lib.hasPrefix prefix jar)
      "passthru.jar ${jar} is not inside ${drv.name}'s output ${drv}";
    assert pkgs.lib.assertMsg (builtins.elem drv.drvPath context)
      "passthru.jar of ${drv.name} does not carry its derivation as context";
    assert pkgs.lib.assertMsg (!pkgs.lib.hasPrefix (placeholder "out") jar)
      "passthru.jar of ${drv.name} is a placeholder";
    jar;
  consumer =
    pkgs.runCommand "clj-build-example-jar-consumer" { } ''
      test -f ${jarPathOf jarJvm}
      ${pkgs.jdk_headless}/bin/java -jar ${jarPathOf jarJvm} '{:name "field"}' > jvm
      grep -F '{:status :ok, :greeting "hello field"}' jvm
      test -f ${jarPathOf jarBb}
      ${pkgs.babashka-unwrapped}/bin/bb ${jarPathOf jarBb} '{:name "field"}' > bb
      grep -F '{:status :ok, :greeting "hello field"}' bb
      touch "$out"
    '';
in
{
  example-runs = runs;
  example-jar-consumer = consumer;
  example-tests-jvm = (clj.mkCljChecks pkgs { src = ../example; tests = [ "example.main-test" ]; inherit deps; name = "example-jvm"; }).clj-tests;
  example-tests-bb = (clj.mkCljChecks pkgs { src = ../example; tests = [ "example.main-test" ]; inherit deps; name = "example-bb"; runtime = "bb"; }).clj-tests;
}
