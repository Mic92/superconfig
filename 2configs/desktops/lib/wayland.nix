{ pkgs, lib, ... }:
{
  imports = [
    ../../alacritty.nix
    ../../mpv.nix
    ../../power-action.nix
    ../../urxvt.nix
    ../../xdg-open.nix
    ../../yubikey.nix
    ../../tmux.nix
    ../../themes.nix
    ../../fonts.nix
    # ../pipewire.nix
    # ./tty-share.nix
    {
      users.users.mainUser.packages = [
        pkgs.sshuttle
      ];
      security.sudo.extraConfig = ''
        lass ALL= (root) NOPASSWD:SETENV: ${pkgs.sshuttle}/bin/.sshuttle-wrapped
      '';
    }
  ];
  users.users.mainUser.extraGroups = [ "audio" "pipewire" "video" "input" ];

  xdg.portal.enable = true;
  xdg.portal.wlr.enable = true;
  fonts.enableDefaultPackages = true;

  security.polkit.enable = true;
  security.pam.services.swaylock = { };

  programs.dconf.enable = lib.mkDefault true;
  programs.xwayland.enable = lib.mkDefault true;

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  programs.wshowkeys.enable = true;

  environment.systemPackages = with pkgs; [
    qtile
    swaylock-effects # lockscreen
    pavucontrol
    swayidle
    rofi-wayland
    rofi-rbw
    gnome.eog
    libnotify
    mako # notifications
    kanshi # auto-configure display outputs
    wdisplays # buggy with qtile?
    wlr-randr
    wl-clipboard
    wev
    blueberry
    grim # screenshots
    wtype

    pavucontrol
    evince
    libnotify
    pamixer
    gnome.file-roller
    xdg-utils
    # polkit agent
    polkit_gnome

    # gtk3 themes
    gsettings-desktop-schemas
    (pkgs.writers.writeDashBin "pass_menu" ''
      set -efux
      password=$(
        (cd $HOME/.password-store; find -type f -name '*.gpg') |
          sed -e 's/\.gpg$//' |
          rofi -dmenu -p 'Password: ' |
          xargs -I{} pass show {} |
          tr -d '\n'
      )
      echo -n "$password" | ${pkgs.wtype}/bin/wtype -d 10 -s 400 -
    '')
  ];

  environment.pathsToLink = [
    "/libexec" # for polkit
    "/share/gsettings-schemas" # for XDG_DATA_DIRS
  ];

  qt.platformTheme = "qt5ct";
}
