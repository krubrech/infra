# octoDNS provider for deSEC — not in nixpkgs, so packaged here.
# Injected into `octodns.withProviders` via `ps.callPackage`, so it builds
# against the same `octodns` python module the wrapper uses.
#
# To bump: set version, then `nix store prefetch-file --json \
#   https://files.pythonhosted.org/packages/source/o/octodns-desec/octodns_desec-<v>.tar.gz`
# and paste the reported hash.
{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  octodns,
  requests,
}:
buildPythonPackage rec {
  pname = "octodns-desec";
  version = "1.3.0";
  pyproject = true;

  src = fetchPypi {
    pname = "octodns_desec";
    inherit version;
    hash = "sha256-TKy2OGXEEM/UP9XatCmmiquAFcj4K6yaGlQrbiX+5ak=";
  };

  build-system = [ setuptools ];

  dependencies = [
    octodns
    requests
  ];

  pythonImportsCheck = [ "octodns_desec" ];

  meta = {
    description = "deSEC.io provider for octoDNS";
    homepage = "https://github.com/rootshell-labs/octodns-desec";
    license = lib.licenses.mit;
  };
}
