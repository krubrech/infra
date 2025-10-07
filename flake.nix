{
  description = "General infra for all projects & servers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url   = "github:nix-community/disko";
    sops-nix.url = "github:Mic92/sops-nix";

    # Optional project flakes (declare as many as you want; can be private via SSH)
    # inputs.my-phx-app.url = "github:YOUR_ORG/phoenix-app";
    # inputs.nextjs-site.url = "github:YOUR_ORG/nextjs-site";
  };

  outputs = { self, nixpkgs, disko, sops-nix, ... }@inputs:
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
        ./modules/base.nix
        ./modules/trusted-keys.nix
        ./modules/users.nix
        ./modules/nixbuild.nix
        ./hosts/rabbit/disk.nix
        ./hosts/rabbit/hardware-configuration.nix
        ./hosts/rabbit/configuration.nix
      ];

      # Add more servers here…
      # home-lab-1 = mkHost "home-lab-1" "aarch64-linux" [ ... ];
    };
  };
}
