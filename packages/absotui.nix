{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "absotui";
  version = "0.5.30-beta";

  src = fetchFromGitHub {
    owner = "pdwaldrop";
    repo = "Absotui";
    rev = "139eb7559dcb9214a7a1ae3bbd50362066334e62";
    hash = "sha256-7UYOi4OI643uzZIamR+FXErZhGwJ8iVFqLWeTmSK/a8=";
  };

  cargoHash = "sha256-3bPg3EwOlZHcWfB8TphLQ/hvuhmAIGySwHh57vpGFVw=";

  postInstall = ''
    install -Dm444 linux/absotui.svg "$out/share/icons/hicolor/scalable/apps/absotui.svg"
  '';

  meta = {
    description = "Terminal user interface client for Audiobookshelf";
    homepage = "https://github.com/pdwaldrop/Absotui";
    license = lib.licenses.gpl3Only;
    mainProgram = "absotui";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
