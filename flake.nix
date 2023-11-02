{
  description = "Tool for doctors to summarize doctor-patient conversations";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.05";
    /*apoc-jar = {
      # To find the exact version of apoc to download, you can manually
      # download the tar.gz file the nixpkgs version of neo4j
      # downloads and check inside the labs directory.
      url = "https://github.com/neo4j-contrib/neo4j-apoc-procedures/releases/download/4.4.0.8/apoc-4.4.0.8-core.jar";
      flake = false;
    };*/
    audio = {
      # type = "git";
      # url = "file:///home/einargs/Coding/Python/visitNotes/";
      url = "github:einargs/visitNotes/vm-conf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    query = {
      # type = "git";
      # url = "file:///home/einargs/Coding/Python/tnhimss-bill/";
      url = "github:einargs/tnhimss-bill/openai";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  nixConfig = {
    bash-prompt = ''\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]dev-shell:\w]\$\[\033[0m\] '';
  };

  outputs = { self, nixpkgs, audio, query, nixos-generators }: 
  let system = "x86_64-linux";
      latest-neo4j = fetchTarball {
            url = "https://neo4j.com/artifact.php?name=neo4j-community-5.13.0-unix.tar.gz";
            sha256 = "0zn282x67wvl8dd0ss4gx7xazvygmg6f2a7vb15hmp06rlzclznh";
          };
      neo4j-overlay = final: prev: {
        neo4j = (prev.neo4j.overrideAttrs {
          version = "5.13.0";
          src = latest-neo4j;
          installPhase = with pkgs; ''
            mkdir -p "$out/share/neo4j"
            cp -R * "$out/share/neo4j"

            mkdir -p "$out/bin"
            for NEO4J_SCRIPT in neo4j neo4j-admin cypher-shell
            do
                chmod +x "$out/share/neo4j/bin/$NEO4J_SCRIPT"
                makeWrapper "$out/share/neo4j/bin/$NEO4J_SCRIPT" \
                    "$out/bin/$NEO4J_SCRIPT" \
                    --prefix PATH : "${lib.makeBinPath [ jdk17 which gawk ]}" \
                    --set JAVA_HOME "${jdk17}"
            done

            patchShebangs $out/share/neo4j/bin/neo4j-admin
            # user will be asked to change password on first login
            $out/bin/neo4j-admin dbms set-initial-password pleaseletmein
          '';
        });
      };
      pkgs = import nixpkgs {
        inherit system;
        config.permittedInsecurePackages = [
          "openssl-1.1.1v" # enabled for audio because of azure-speech
          "openssl-1.1.1w" # enabled for audio because of azure-speech
        ];
        overlays = [neo4j-overlay];
      };
      azure-image = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          apoc-jar = "${latest-neo4j}/labs/apoc-5.13.0-core.jar";
          audio-site = audio.packages.${system}.site;
          query-site = query.packages.${system}.site;
        };
        modules = [
          ({config, pkgs, ...}: {
            nixpkgs.overlays = [neo4j-overlay];
          })
          nixos-generators.nixosModules.all-formats
          ./vm.nix
          audio.nixosModules.backend
          query.nixosModules.backend
        ];
      };
  in {

    # To get an image we can deploy to azure do:
    # nix build .#nixosConfigurations.my-machine.config.formats.azure
    nixosConfigurations.azure-vm = azure-image;

    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        azure-cli
      ];
      src = [
        ./flake.nix
        ./flake.lock
      ];
    };
  };
}
