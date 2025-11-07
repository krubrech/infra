{
  description = "General infra for all projects & servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url   = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixfiles.url = "git+ssh://git@github.com/krubrech/nixfiles.git?shallow=1";
    nixfiles.inputs.nixpkgs.follows = "nixpkgs";
    nixfiles.inputs.home-manager.follows = "home-manager";

    # Optional project flakes (declare as many as you want; can be private via SSH)
    # inputs.my-phx-app.url = "github:YOUR_ORG/phoenix-app";
    # inputs.nextjs-site.url = "github:YOUR_ORG/nextjs-site";
  };

  outputs = { self, nixpkgs, disko, sops-nix, home-manager, nixfiles, ... }@inputs:
  let
    systems = [ "x86_64-linux" "aarch64-linux" ];
    lib = nixpkgs.lib;
    mkHost = name: system: modules: lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };  # give modules access to project flakes
      modules = modules;
    };
  in {
    nixosConfigurations = {
      hetzner-pony = mkHost "pony" "x86_64-linux" [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        ./modules/base.nix
        ./modules/wireguard.nix
        ./modules/nginx.nix
        ./modules/apps.nix
        ./hosts/hetzner-pony/disk.nix
        ./hosts/hetzner-pony/hardware-configuration.nix
        ./hosts/hetzner-pony/configuration.nix
      ];

      rabbit = mkHost "rabbit" "x86_64-linux" [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        ./modules/base.nix
        ./modules/wireguard.nix
        ./modules/trusted-keys.nix
        ./modules/users.nix
        ./hosts/rabbit/disk.nix
        ./hosts/rabbit/hardware-configuration.nix
        ./hosts/rabbit/configuration.nix
      ];
      # ./modules/nixbuild.nix

      # Raspberry Pi 5 (mole) - Using Raspberry Pi OS + Nix (not full NixOS)
      # See hosts/mole/setup-pi.sh for installation
      # NixOS config kept for reference but commented out due to Pi 5 compatibility issues
      # mole = mkHost "mole" "aarch64-linux" [
      #   sops-nix.nixosModules.sops
      #   home-manager.nixosModules.home-manager
      #   ./modules/base.nix
      #   ./modules/trusted-keys.nix
      #   ./hosts/mole/configuration.nix
      #   {
      #     home-manager.useGlobalPkgs = false;
      #     home-manager.useUserPackages = true;
      #     home-manager.extraSpecialArgs = { inherit inputs; };
      #     home-manager.users.klaus = import ./hosts/mole/users/klaus.nix;
      #     home-manager.users.kids = import ./hosts/mole/users/kids.nix;
      #   }
      # ];

      # Add more servers here…
      # home-lab-1 = mkHost "home-lab-1" "aarch64-linux" [ ... ];
    };

    # VM for testing rabbit configuration
    packages.x86_64-linux.rabbit-vm =
      self.nixosConfigurations.rabbit.config.system.build.vmWithBootLoader;

    # SD card image build disabled - using Raspberry Pi OS + Nix instead
    # packages.aarch64-linux.mole-sd-image =
    #   self.nixosConfigurations.mole.config.system.build.sdImage;
  };
}
