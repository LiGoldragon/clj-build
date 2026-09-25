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
in
{
  example-runs = runs;
  example-tests-jvm = (clj.mkCljChecks pkgs { src = ../example; tests = [ "example.main-test" ]; inherit deps; name = "example-jvm"; }).clj-tests;
  example-tests-bb = (clj.mkCljChecks pkgs { src = ../example; tests = [ "example.main-test" ]; inherit deps; name = "example-bb"; runtime = "bb"; }).clj-tests;
}
