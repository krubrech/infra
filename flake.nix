{
  description = "General infra for all projects & servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko.url   = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixfiles.url = "github:krubrech/nixfiles";
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
        ./modules/trusted-keys.nix
        ./modules/users.nix
        ./hosts/rabbit/disk.nix
        ./hosts/rabbit/hardware-configuration.nix
        ./hosts/rabbit/configuration.nix
      ];
      # ./modules/nixbuild.nix

      # Add more servers here…
      # home-lab-1 = mkHost "home-lab-1" "aarch64-linux" [ ... ];
    };

    # VM for testing rabbit configuration
    packages.x86_64-linux.rabbit-vm =
      self.nixosConfigurations.rabbit.config.system.build.vmWithBootLoader;
  };
}
