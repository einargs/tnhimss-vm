{ pkgs, modulesPath, apoc-jar, audio-site, query-site, ... }: {
  imports = [
    # For local testing uncomment this
    # ./local.nix
    "${modulesPath}/virtualisation/azure-image.nix"
  ];
  # Enabled because of audio
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
    "openssl-1.1.1v"
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = with pkgs; [
    git
    vim
    tmux
  ];
  networking.firewall.allowedTCPPorts = [ 80 443 8080 ];
  users.mutableUsers = false;
  networking.hostName = "mtsu-tnhimss";

  services.neo4j = {
    enable = true;
    bolt.enable = true;
    directories.imports = "/home/mtsu/neo4j-import";
    directories.plugins = 
      let plugin-dir = pkgs.runCommand ''
      mkdir $out
      ln -s ${apoc-jar} $out/apoc-core.jar
      '';
      in plugin-dir;
  };

  users.users.mtsu = {
    isNormalUser = true;
    home = "/home/mtsu";
    description = "MTSU student";
    extraGroups =
      [ "wheel" # users in wheel are allowed to use sudo
        "disk" "audio" "video" "networkmanager" "systemd-journal"
      ];
    hashedPassword = "$y$j9T$vsRtWjpE4252XW/6CASe3/$wptn/nGTeXFNI1jYEkx1ejVlz6DzoYSNMWDFfhLUF18";
  };
  system.stateVersion = "23.05";
  services.openssh = {
    enable = true;
  };
  services.visit-notes-backend = {
    enable = true;
    port = 8080;
  };
  services.query-backend = {
    enable = true;
    port = 8180;
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "egs3d@mtmail.mtsu.edu";
    certs."audio.einargs.dev".extraDomainNames = [
      "query.einargs.dev"
    ];
  };
  services.nginx = {
    enable = true;
    appendHttpConfig = ''
      upstream audio_backend {
        server 127.0.0.1:8080;
      }
      upstream query_backend {
        server 127.0.0.1:8180;
      }
    '';
    virtualHosts = {
      "audio.einargs.dev" = {
        # We'll turn this on once we have a certificate
        enableACME = true;
        forceSSL = true;
        # addSSL = true;
        locations."/" = {
          root = "${audio-site}/";
          # priority = 100;
        };
        locations."/socket.io/" = {
          # these duplicate some of the stuff in extraConfig
          # recommendedProxySettings = true;
          # proxyWebsockets = true;
          # priority = 50;
          proxyPass = "http://audio_backend"; # The socket.io path is kept
          extraConfig = ''
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $host;

            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          '';
        };
      };
      "query.einargs.dev" = {
        # We'll turn this on once we have a certificate
        forceSSL = true;
        useACMEHost = "audio.einargs.dev";
        locations."/" = {
          root = "${query-site}/";
          # priority = 100;
        };
        locations."/socket.io/" = {
          # these duplicate some of the stuff in extraConfig
          # recommendedProxySettings = true;
          # proxyWebsockets = true;
          # priority = 50;
          proxyPass = "http://query_backend"; # The socket.io path is kept
          extraConfig = ''
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $host;

            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          '';
        };
      };
    };
  };
}
