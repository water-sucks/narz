{
  stdenv,
  lib,
  nix-gitignore,
  zig,
  fetchZigDeps,
  tree,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "narz";
  version = "0.1.0";

  src = nix-gitignore.gitignoreSource [] ./.;

  postPatch = let
    deps = fetchZigDeps {
      inherit stdenv zig;
      name = finalAttrs.pname;
      src = finalAttrs.src;
      depsHash = "sha256-ilhHDbKjGalT4FeOIahjWazCGwA2b48MxDWbPy0KIEU=";
    };
  in ''
    mkdir -p .cache
    ln -s ${deps} .cache/p
  '';

  nativeBuildInputs = [
    zig
    tree
  ];

  dontConfigure = true;
  dontInstall = true;

  buildPhase = ''
    tree .cache/p

    mkdir -p $out
    zig build install \
      --cache-dir $(pwd)/zig-cache \
      --global-cache-dir $(pwd)/.cache \
      -Dcpu=baseline \
      -Doptimize=ReleaseSafe \
      --prefix $out
  '';

  meta = {
    description = "Messing around with Nix NAR archives in Zig";
    homepage = "https://github.com/water-sucks/narz";
    maintainers = with lib.maintainers; [water-sucks];
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
})
