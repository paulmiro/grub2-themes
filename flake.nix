{
  description = "Flake to manage grub2 themes from vinceliuice";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-24.11";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "aarch64-linux" "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      nixosModules.default = self.nixosModules.grub2-theme;
      nixosModules.grub2-theme = { config, ... }:
        forAllSystems (system:
          let pkgs = nixpkgsFor.${system}; in
          let
            cfg = config.boot.loader.grub2-theme;
            footer = pkgs.lib.trivial.boolToString cfg.footer;
            resolution =
              if cfg.custom.resolution != null
              then cfg.custom.resolution
              else {
                "1080p" = "1920x1080";
                "ultrawide" = "2560x1080";
                "2k" = "2560x1440";
                "4k" = "3840x2160";
                "ultrawide2k" = "3440x1440";
              }."${cfg.screen}";
            splashImage =
              if cfg.splashImage != null
              then cfg.splashImage
              else "";
            bootMenuConfig =
              if cfg.custom.bootMenuConfig != null
              then cfg.custom.bootMenuConfig
              else "";
            terminalConfig =
              if cfg.custom.terminalConfig != null
              then cfg.custom.terminalConfig
              else "";
            grub2-theme = pkgs.stdenv.mkDerivation {
              name = "grub2-theme";
              src = "${self}";
              buildInputs = [ pkgs.imagemagick ];
              installPhase = ''
                mkdir -p $out/grub/themes

                # Create placeholder terminal box PNGs that install.sh expects
                mkdir -p common
                for box in c e n ne nw s se sw w; do
                  touch common/terminal_box_$box.png
                done

                # Run the install script
                bash ./install.sh \
                  --generate $out/grub/themes \
                  --screen ${cfg.screen} \
                  --theme ${cfg.theme} \
                  --icon ${cfg.icon} \
                  ${if cfg.custom.resolution != null then "--custom-resolution ${cfg.custom.resolution}" else ""}

                if [ -n "${splashImage}" ]; then
                  rm $out/grub/themes/${cfg.theme}/background.jpg;
                  ${pkgs.imagemagick}/bin/magick ${splashImage} $out/grub/themes/${cfg.theme}/background.jpg;
                fi;

                if [ ${footer} == "false" ]; then
                  sed -i ':again;$!N;$!b again; s/\+ image {[^}]*}//g' $out/grub/themes/${cfg.theme}/theme.txt;
                fi;

                if [ -n "${bootMenuConfig}" ]; then
                  sed -i ':again;$!N;$!b again; s/\+ boot_menu {[^}]*}//g' $out/grub/themes/${cfg.theme}/theme.txt;
                  cat << EOF >> $out/grub/themes/${cfg.theme}/theme.txt
                + boot_menu {
                    ${bootMenuConfig}
                }
                EOF
                fi;

                if [ -n "${terminalConfig}" ]; then
                  sed -i 's/^terminal-.*$//g' $out/grub/themes/${cfg.theme}/theme.txt
                  cat << EOF >> $out/grub/themes/${cfg.theme}/theme.txt
                ${terminalConfig}
                EOF
                fi;
              '';
            };
          in
          {
            options = with pkgs.lib; {
              boot.loader.grub2-theme = {
                enable = mkOption {
                  default = false;
                  example = true;
                  type = types.bool;
                  description = ''
                    Enable grub2 theming
                  '';
                };
                baseTheme = mkOption {
                  default = "tela";
                  example = "vimix";
                  type = types.enum [ "tela" "vimix" "stylish" "whitesur" "sicher" ];
                  description = ''
                    The theme to use for grub2.
                  '';
                };
                iconTheme = mkOption {
                  default = "white";
                  example = "color";
                  type = types.enum [ "color" "white" "whitesur" ];
                  description = ''
                    The icon to use for grub2.
                  '';
                };
                screenSize = mkOption {
                  default = "1080p";
                  example = "4k";
                  type = types.enum [ "1080p" "2k" "4k" "ultrawide" "ultrawide2k" ];
                  description = ''
                    The screen resolution to use for grub2.
                  '';
                };
                footer = mkOption {
                  default = true;
                  example = false;
                  type = types.bool;
                  description = ''
                    Whether to include the image footer.
                  '';
                };
                custom = {
                  resolution = mkOption {
                    default = null;
                    example = "1600x900";
                    type = types.nullOr (types.strMatching "[0-9]+x[0-9]+");
                    description = ''
                      Custom resolution for grub2 theme. Should be in the format "WIDTHxHEIGHT".
                      If set, this will override the 'screen' option.
                    '';
                  };
                  splashImage = mkOption {
                    default = null;
                    example = "/my/path/background.jpg";
                    type = types.nullOr types.path;
                    description = ''
                      The path of the image to use for background (must be jpg or png).
                    '';
                  };
                  bootMenuConfig = mkOption {
                    default = "";
                    example = "left = 30%";
                    type = types.str;
                    description = ''
                      Grub theme definition for boot_menu.
                      Refer to config/theme-*.txt for reference.
                    '';
                  };
                  terminalConfig = mkOption {
                    default = null;
                    example = "terminal-font: \"Terminus Regular 18\"";
                    type = types.nullOr types.str;
                    description = ''
                      Replaces grub theme definition for terminial-*.
                      Refer to config/theme-*.txt for reference.
                    '';
                  };
                };
              };
            };
            config = pkgs.lib.mkIf cfg.enable {
              boot.loader.grub = {
                theme = "${grub2-theme}/grub/themes/${cfg.theme}";
                splashImage = "${grub2-theme}/grub/themes/${cfg.theme}/background.jpg";
                gfxmodeEfi = "${resolution},auto";
                gfxmodeBios = "${resolution},auto";
                extraConfig = ''
                  insmod gfxterm
                  insmod png
                  set icondir=($root)/theme/icons
                '';
              };
            };
          });
    };
}
