{ self, config, lib, pkgs, ... }:
{
  imports = [
    ./binary-cache/client.nix
    ./gc.nix
    ./mc.nix
    ./zsh.nix
    ./htop.nix
    ./wiregrill.nix
    ./tmux.nix
    ./tor-ssh.nix
    ./networkd.nix
    ./pinned-registry.nix
    self.inputs.stockholm.nixosModules.users
    self.inputs.stockholm.nixosModules.hosts
    self.inputs.stockholm.nixosModules.kartei
    self.inputs.stockholm.nixosModules.build
    self.inputs.stockholm.nixosModules.dns
    self.inputs.stockholm.nixosModules.exim
    self.inputs.stockholm.nixosModules.exim-retiolum
    self.inputs.stockholm.nixosModules.tinc
    self.inputs.stockholm.nixosModules.iptables
    self.inputs.stockholm.nixosModules.power-action
    self.inputs.stockholm.nixosModules.setuid
    self.inputs.stockholm.nixosModules.secret
    self.inputs.stockholm.nixosModules.sitemap
    self.inputs.stockholm.nixosModules.ssl
    self.inputs.stockholm.nixosModules.systemd
    self.inputs.stockholm.nixosModules.xresources
    self.inputs.stockholm.nixosModules.ssh
    self.inputs.stockholm.nixosModules.sync-containers3
    {
      users.extraUsers.mainUser.hashedPasswordFile = "${config.krebs.secret.directory}/passwordHash";
      users.extraUsers.root.hashedPasswordFile = "${config.krebs.secret.directory}/passwordHash";
      clanCore.secrets.password = {
        secrets.password = { };
        secrets.passwordHash = { };
        generator = ''
          ${pkgs.xkcdpass}/bin/xkcdpass -n 4 -d - > $secrets/password
          cat $secrets/password | ${pkgs.mkpasswd}/bin/mkpasswd -s -m sha-512 > $secrets/passwordHash
        '';
      };
    }
    {
      services.openssh.enable = true;
      services.openssh.hostKeys = [{
        path = "${config.krebs.secret.directory}/ssh.id_ed25519";
        type = "ed25519";
      }];
      clanCore.secrets.ssh = {
        secrets."ssh.id_ed25519" = { };
        facts."ssh.id_ed25519.pub" = { };
        generator = ''
          ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f $secrets/ssh.id_ed25519
          mv $secrets/ssh.id_ed25519.pub $facts/ssh.id_ed25519.pub
        '';
      };
    }
    {
      users.extraUsers = {
        root = {
          openssh.authorizedKeys.keys = [
            config.krebs.users.lass.pubkey
          ];
        };
        mainUser = {
          name = "lass";
          uid = 1337;
          home = "/home/lass";
          group = "users";
          createHome = true;
          useDefaultShell = true;
          isNormalUser = true;
          extraGroups = [
            "audio"
            "video"
            "fuse"
            "wheel"
            "tor"
          ];
          openssh.authorizedKeys.keys = [
            config.krebs.users.lass.pubkey
          ];
        };
      };
    }
    (let ca-bundle = "/etc/ssl/certs/ca-bundle.crt"; in {
      environment.variables = {
        CURL_CA_BUNDLE = ca-bundle;
        GIT_SSL_CAINFO = ca-bundle;
        SSL_CERT_FILE = ca-bundle;
      };
    })
    {
      #for sshuttle
      environment.systemPackages = [
        pkgs.python3Packages.python
      ];
    }
  ];

  networking.hostName = config.krebs.build.host.name;

  krebs = {
    enable = true;
    build.user = config.krebs.users.lass;
    ssl.trustIntermediate = true;
  };

  nix.useSandbox = true;

  users.mutableUsers = false;

  # multiple-definition-problem when defining environment.variables.EDITOR
  environment.extraInit = ''
    EDITOR=vim
  '';

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    self.packages.${pkgs.system}.vim

  #stockholm
    deploy
    git
    git-absorb
    git-preview
    gnumake
    jq
    nix-output-monitor

  #style
    rxvt-unicode-unwrapped.terminfo
    alacritty.terminfo

  #monitoring tools
    htop
    iotop

  #network
    iptables
    iftop
    tcpdump
    mosh
    eternal-terminal
    sshify

  #stuff for dl
    aria2

  #neat utils
    file
    hashPassword
    kpaste
    cyberlocker-tools
    pciutils
    pop
    q
    rs
    untilport
    (pkgs.writeDashBin "urgent" ''
      printf '\a'
    '')
    usbutils
    logify
    goify

  #unpack stuff
    libarchive

    (pkgs.writeDashBin "sshn" ''
      ${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$@"
    '')
  ];

  environment.shellAliases = {
    ll = "ls -l";
    la = "ls -la";
    ls = "ls --color";
    ip = "ip -color=auto";
    grep = "grep --color=auto";
  };

  programs.bash = {
    enableCompletion = true;
    interactiveShellInit = ''
      HISTCONTROL='erasedups:ignorespace'
      HISTSIZE=65536
      HISTFILESIZE=$HISTSIZE

      shopt -s checkhash
      shopt -s histappend histreedit histverify
      shopt -s no_empty_cmd_completion
      complete -d cd
      LS_COLORS=$LS_COLORS:'di=1;31:' ; export LS_COLORS
    '';
    promptInit = ''
      if test $UID = 0; then
        PS1='\[\033[1;31m\]\w\[\033[0m\] '
        PROMPT_COMMAND='echo -ne "\033]0;$$ $USER@$PWD\007"'
      elif test $UID = 1337; then
        PS1='\[\033[1;32m\]\w\[\033[0m\] '
        PROMPT_COMMAND='echo -ne "\033]0;$$ $PWD\007"'
      else
        PS1='\[\033[1;33m\]\u@\w\[\033[0m\] '
        PROMPT_COMMAND='echo -ne "\033]0;$$ $USER@$PWD\007"'
      fi
      if test -n "$SSH_CLIENT"; then
        PS1='\[\033[35m\]\h'" $PS1"
        PROMPT_COMMAND='echo -ne "\033]0;$$ $HOSTNAME $USER@$PWD\007"'
      fi
    '';
  };

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    RuntimeMaxUse=128M
    Storage=persistent
  '';

  krebs.iptables = {
    enable = true;
    tables = {
      nat.PREROUTING.rules = [
        { predicate = "-i retiolum -p tcp -m tcp --dport 22"; target = "ACCEPT"; }
        { predicate = "-i wiregrill -p tcp -m tcp --dport 22"; target = "ACCEPT"; }
        { predicate = "-p tcp -m tcp --dport 22"; target = "REDIRECT --to-ports 0"; }
        { predicate = "-p tcp -m tcp --dport 45621"; target = "REDIRECT --to-ports 22"; }
      ];
      nat.OUTPUT.rules = [
        { predicate = "-o lo -p tcp -m tcp --dport 45621"; target = "REDIRECT --to-ports 22"; }
      ];
      filter.INPUT.policy = "DROP";
      filter.FORWARD.policy = "DROP";
      filter.INPUT.rules = lib.mkMerge [
        (lib.mkBefore [
          { predicate = "-m conntrack --ctstate RELATED,ESTABLISHED"; target = "ACCEPT"; }
          { predicate = "-p icmp"; target = "ACCEPT"; }
          { predicate = "-p ipv6-icmp"; target = "ACCEPT"; v4 = false;  }
          { predicate = "-i lo"; target = "ACCEPT"; }
          { predicate = "-p tcp --dport 22"; target = "ACCEPT"; }
        ])
        (lib.mkOrder 1000 [
          { predicate = "-i retiolum -p udp --dport 60000:61000"; target = "ACCEPT"; }
          { predicate = "-i retiolum -p udp -m udp --dport 53"; target = "ACCEPT"; }
          { predicate = "-i retiolum -p tcp --dport 19999"; target = "ACCEPT"; }
        ])
        (lib.mkAfter [
          { predicate = "-p tcp -i retiolum"; target = "REJECT --reject-with tcp-reset"; }
          { predicate = "-p udp -i retiolum"; target = "REJECT --reject-with icmp-port-unreachable"; v6 = false; }
          { predicate = "-i retiolum"; target = "REJECT --reject-with icmp-proto-unreachable"; v6 = false; }
        ])
      ];
    };
  };

  networking.dhcpcd.extraConfig = ''
    noipv4ll
  '';

  networking.extraHosts = ''
    10.42.0.1 styx.gg23
  '';

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # use 24:00 time format, the default got sneakily changed around 20.03
  i18n.defaultLocale = lib.mkDefault "C.UTF-8";
  time.timeZone = lib.mkDefault"Europe/Berlin";

  # disable doc usually
  documentation.nixos.enable = lib.mkDefault false;
}
