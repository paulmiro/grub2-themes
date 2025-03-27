{
  description = "Flake to manage grub2 themes from vinceliuice";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.11";
  };

  outputs = { self, ... }: {
    nixosModules.default = self.nixosModules.grub2-theme;
    nixosModules.grub2-theme = { config, lib, pkgs, ... }:
      let
        cfg = config.boot.loader.grub2-theme;
        footer = lib.trivial.boolToString cfg.footer;
        resolution =
          if cfg.custom.resolution != null
          then cfg.custom.resolution
          else {
            "1080p" = "1920x1080";
            "ultrawide" = "2560x1080";
            "2k" = "2560x1440";
            "4k" = "3840x2160";
            "ultrawide2k" = "3440x1440";
          }."${cfg.screenSize}";
        splashImage =
          if cfg.custom.splashImage != null
          then cfg.custom.splashImage
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
          src = "${./.}";
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
              --screen ${cfg.screenSize} \
              --theme ${cfg.theme} \
              --icon ${cfg.iconTheme} \
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
        options = {
          boot.loader.grub2-theme = {
            enable = lib.mkOption {
              default = false;
              example = true;
              type = lib.types.bool;
              description = ''
                Enable grub2 theming
              '';
            };
            theme = lib.mkOption {
              default = "tela";
              example = "vimix";
              type = lib.types.enum [ "tela" "vimix" "stylish" "whitesur" "sicher" ];
              description = ''
                The theme to use for grub2.
              '';
            };
            iconTheme = lib.mkOption {
              default = "white";
              example = "color";
              type = lib.types.enum [ "color" "white" "whitesur" ];
              description = ''
                The icon to use for grub2.
              '';
            };
            screenSize = lib.mkOption {
              default = "1080p";
              example = "4k";
              type = lib.types.enum [ "1080p" "2k" "4k" "ultrawide" "ultrawide2k" ];
              description = ''
                The screen resolution to use for grub2.
              '';
            };
            footer = lib.mkOption {
              default = true;
              example = false;
              type = lib.types.bool;
              description = ''
                Whether to include the image footer.
              '';
            };
            custom = {
              resolution = lib.mkOption {
                default = null;
                example = "1600x900";
                type = lib.types.nullOr (lib.types.strMatching "[0-9]+x[0-9]+");
                description = ''
                  Custom resolution for grub2 theme. Should be in the format "WIDTHxHEIGHT".
                  If set, this will override the 'screen' option.
                '';
              };
              splashImage = lib.mkOption {
                default = null;
                example = "/my/path/background.jpg";
                type = lib.types.nullOr lib.types.path;
                description = ''
                  The path of the image to use for background (must be jpg or png).
                '';
              };
              bootMenuConfig = lib.mkOption {
                default = "";
                example = "left = 30%";
                type = lib.types.str;
                description = ''
                  Grub theme definition for boot_menu.
                  Refer to config/theme-*.txt for reference.
                '';
              };
              terminalConfig = lib.mkOption {
                default = null;
                example = "terminal-font: \"Terminus Regular 18\"";
                type = lib.types.nullOr lib.types.str;
                description = ''
                  Replaces grub theme definition for terminial-*.
                  Refer to config/theme-*.txt for reference.
                '';
              };
            };
          };
        };
        config = lib.mkIf cfg.enable {
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
      };
  };
}
