{
  config,
  lib,
  pkgs,
  hab,
  ...
}:

let
  homeDirectory = config.home.homeDirectory;
  hermesEnv = "${homeDirectory}/.config/hermes/hermes.env";
  hermesBin = "${homeDirectory}/.nix-profile/bin/hermes";

  localDeploymentFile = "/etc/nixos/local/deployment.json";
  bootstrapDeploymentFile = "/etc/nixos/deployment.json";
  deploymentFile =
    if builtins.pathExists localDeploymentFile then
      localDeploymentFile
    else
      bootstrapDeploymentFile;
  deployment =
    if builtins.pathExists deploymentFile then
      builtins.fromJSON (builtins.readFile deploymentFile)
    else
      { };
  hermesDeployment =
    if deployment ? hermes then
      if builtins.isAttrs deployment.hermes then
        deployment.hermes
      else
        throw "local/deployment.json hermes must be an attribute set"
    else
      { };
  habUrl =
    if hermesDeployment ? habUrl then
      if builtins.isString hermesDeployment.habUrl then
        hermesDeployment.habUrl
      else
        throw "local/deployment.json hermes.habUrl must be a string"
    else
      "";
  ollamaBaseUrl =
    if hermesDeployment ? ollamaBaseUrl then
      if builtins.isString hermesDeployment.ollamaBaseUrl then
        hermesDeployment.ollamaBaseUrl
      else
        throw "local/deployment.json hermes.ollamaBaseUrl must be a string"
    else
      "";

  waitForHermesChromium = pkgs.writeShellScript "wait-for-hermes-chromium" ''
    set -eu

    for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
      if ${pkgs.curl}/bin/curl \
        --fail \
        --silent \
        --max-time 1 \
        http://127.0.0.1:9223/json/version \
        >/dev/null 2>&1
      then
        exit 0
      fi

      ${pkgs.coreutils}/bin/sleep 0.1
    done

    echo "Chromium CDP endpoint did not become ready" >&2
    exit 1
  '';

  habRaw = pkgs.stdenv.mkDerivation {
    pname = "hab";
    version = "latest";
    src = hab;
    dontUnpack = true;

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.glibc ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      install -m 0755 "$src" "$out/bin/hab"
      runHook postInstall
    '';
  };

  habPackage = pkgs.writeShellScriptBin "hab" ''
    hermes_env="${hermesEnv}"

    if [ -r "$hermes_env" ]; then
      set -a
      . "$hermes_env"
      set +a
    fi

${lib.optionalString (habUrl != "") ''
    export HAB_URL="''${HAB_URL:-${habUrl}}"
''}
    export HAB_SKIP_UPDATE_CHECK="''${HAB_SKIP_UPDATE_CHECK:-1}"

    if [ -z "''${HAB_URL:-}" ]; then
      echo "HAB_URL is not configured; set hermes.habUrl in /etc/nixos/local/deployment.json or HAB_URL in $hermes_env" >&2
      exit 1
    fi

    if [ -z "''${HAB_TOKEN:-}" ] && [ -n "''${HASS_TOKEN:-}" ]; then
      export HAB_TOKEN="$HASS_TOKEN"
    fi

    if [ -z "''${HA_ACCESS_TOKEN:-}" ] && [ -n "''${HASS_TOKEN:-}" ]; then
      export HA_ACCESS_TOKEN="$HASS_TOKEN"
    fi

    exec ${habRaw}/bin/hab "$@"
  '';

  mcpNodeRed = pkgs.callPackage ../packages/mcp-node-red.nix { };

  nodeRedFileMcp = pkgs.writeShellScriptBin "node-red-file-mcp" ''
    exec ${pkgs.python3}/bin/python3 ${../packages/node-red-file-mcp.py}
  '';
in
{
  xdg.desktopEntries.hermes-terminal = {
    name = "Hermes Terminal";
    genericName = "Hermes session browser";
    exec = "${pkgs.kitty}/bin/kitty --class hermes-terminal --title \"Hermes Terminal\" ${hermesBin} sessions browse";
    icon = "utilities-terminal";
    categories = [
      "Development"
      "Utility"
    ];
    terminal = false;
  };

  programs.bash.initExtra = ''
    source <("$HOME/.nix-profile/bin/hermes" completion bash)
  '';

  programs.hermes-agent = {
    enable = true;
    desktop.enable = true;
  };

  services.hermes-agent = {
    enable = true;

    gateway.enable = false;

    environmentFiles = [
      hermesEnv
    ];

    environment = {
      HAB_SKIP_UPDATE_CHECK = "1";
    }
    // lib.optionalAttrs (habUrl != "") {
      HAB_URL = habUrl;
    };

    extraPackages = [
      pkgs.chromium
      habPackage
      mcpNodeRed
    ];

    mcpServers.node-red = {
      command = "${mcpNodeRed}/bin/mcp-node-red";
      env.NODE_RED_URL = "\${NODE_RED_URL}";
    };

    mcpServers.node-red-files = {
      command = "${nodeRedFileMcp}/bin/node-red-file-mcp";
      env.NODE_RED_URL = "\${NODE_RED_URL}";
    };

    settings = {
      _config_version = 37;

      model = {
        provider = "openai-codex";
        default = "gpt-5.6-terra";
      };

      agent = {
        reasoning_effort = "medium";
        api_max_retries = 10;

        personalities = {
          "gemma-research" = ''
            For current, changing, or externally verifiable information, use tools
            instead of relying on training knowledge.

            When researching:
            - Use web tools for current information.
            - Open and read at least one appropriate primary source.
            - Extract the decisive fact directly from the retrieved source.
            - Prefer primary sources over search-result summaries.
            - If search results, prior knowledge, and a primary source disagree,
              trust the primary source.
            - Never claim that a source confirms something unless that information
              was actually present in the retrieved tool result.
            - Verify important conclusions before answering.
          '';
        };
      };

      fallback_providers = [
        {
          provider = "openrouter";
          model = "nvidia/nemotron-3-ultra-550b-a55b:free";
        }
      ]
      ++ lib.optional (ollamaBaseUrl != "") {
        provider = "custom";
        model = "gemma4:12b";
        base_url = ollamaBaseUrl;
        key_env = "OLLAMA_API_KEY";
      };

      providers = lib.optionalAttrs (ollamaBaseUrl != "") {
        ollama = {
          name = "Ollama";
          api = ollamaBaseUrl;
          key_env = "OLLAMA_API_KEY";
          transport = "chat_completions";
          discover_models = false;

          models = {
            "llama3.1:8b-instruct-q4_K_M" = {
              context_length = 131072;
            };

            "hf.co/maxwellb-hf/gemma4-12b-it-oym:Q4_K_S" = {
              context_length = 131072;
              supports_vision = true;
            };

            "gemma4:12b-it-qat" = {
              context_length = 262144;
              supports_vision = true;
            };

            "gemma4:12b" = {
              context_length = 262144;
              supports_vision = true;
            };
          };
        };
      };

      web.backend = "firecrawl";

      toolsets = [
        "hermes-cli"
        "browser"
      ];

      browser = {
        backend = "off";
        cloud_provider = "local";
        cdp_url = "http://127.0.0.1:9222";
        command_timeout = 30;
      };
    };
  };

  systemd.user.sockets.hermes-chromium-cdp = {
    Unit.Description = "Socket for Hermes Chromium CDP";
    Socket = {
      ListenStream = "127.0.0.1:9222";
      NoDelay = true;
    };
    Install.WantedBy = [ "sockets.target" ];
  };

  systemd.user.services.hermes-chromium-backend = {
    Unit = {
      Description = "Chromium backend for Hermes CDP";
      StopWhenUnneeded = true;
    };

    Service = {
      ExecStart = ''
        ${pkgs.chromium}/bin/chromium \
          --headless=new \
          --remote-debugging-address=127.0.0.1 \
          --remote-debugging-port=9223 \
          --user-data-dir=%t/hermes-chromium-cdp \
          --no-first-run \
          --no-default-browser-check \
          about:blank
      '';
      ExecStartPost = waitForHermesChromium;
      KillMode = "mixed";
      TimeoutStopSec = 10;
    };
  };

  systemd.user.services.hermes-chromium-cdp = {
    Unit = {
      Description = "On-demand proxy for Hermes Chromium CDP";
      BindsTo = [ "hermes-chromium-backend.service" ];
      After = [ "hermes-chromium-backend.service" ];
    };

    Service.ExecStart = ''
      ${pkgs.systemd}/lib/systemd/systemd-socket-proxyd \
        --exit-idle-time=10min \
        127.0.0.1:9223
    '';
  };

  home.packages = [
    habPackage
    mcpNodeRed
  ];
}
