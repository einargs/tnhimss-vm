{
  description = "Tool for doctors to summarize doctor-patient conversations";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.05";
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
      pkgs = import nixpkgs {
        inherit system;
        config.permittedInsecurePackages = [
          "openssl-1.1.1v" # enabled for audio because of azure-speech
          "openssl-1.1.1w" # enabled for audio because of azure-speech
        ];
      };
      azure-image = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          audio-site = audio.packages.${system}.site;
          query-site = query.packages.${system}.site;
        };
        modules = [
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
