#!/usr/bin/env zsh

configure_locale() {
    localectl set-keymap --no-convert us
    rm /etc/localtime
    ln -s /usr/share/zoneinfo/US/Eastern /etc/localtime
}

configure_sound() {
    cp /vagrant/snd-hda-intel.conf /etc/modprobe.d/
    rmmod snd-hda-intel && modprobe snd-hda-intel
    pacman --noconfirm -S alsa-utils
    cp /vagrant/asound.state /var/lib/alsa/
}

user=smcleod
add_user() {
    hash1='$6$tnqtn6XWkBYE1QqS$YXUw9gxGlbp974ZGWn7c.lJwuCr40gL46'
    hash2='sdRrKDsBLq6pzMlBTFDBwH85oqW96nMhvXpjfHYjfLs49DDYFkvy0'
    useradd -m -G wheel,audio -s /usr/bin/zsh -p ${hash1}${hash2} ${user}
    mkdir /home/smcleod/Dropbox
}

setup_ssh() {
    mkdir -p /home/${user}/.ssh
    cp /vagrant_ssh/id_rsa /home/${user}/.ssh/
    echo 'StrictHostKeyChecking no' >> /home/${user}/.ssh/config
    chown -R ${user}:${user} /home/${user}/.ssh
    chmod 0600 /home/${user}/.ssh/id_rsa
}

secure_system() {
    passwd -l vagrant
    rm /home/${user}/.ssh/config
}

setup_gnupg() {
    cp -R /vagrant_gnupg /home/${user}/.gnupg
    chown -R ${user}:${user} /home/${user}/.gnupg
    echo "keyring /etc/pacman.d/gnupg/pubring.gpg" >> /home/${user}/.gnupg/gpg.conf
}

install_aura() {
cat <<'EOF' >> /etc/pacman.conf
[archlinuxfr]
  SigLevel = Never
  Server = http://repo.archlinux.fr/$arch
EOF
    pacman --noconfirm -Syu
    pacman --noconfirm -S yaourt
    sudo -iu smcleod yaourt --noconfirm -S powerpill aura-bin
}

clone_repos() {
sudo -iu smcleod zsh <<EOF
  git clone git@github.com:halcyon/dotfiles.git
  cd dotfiles; ./stow.sh; cd ..
  git clone git@bitbucket.org:halcyonblue/dotfiles-private.git
  cd dotfiles-private; ./stow.sh; cd ..
  git clone https://github.com/robbyrussell/oh-my-zsh.git .oh-my-zsh
  mkdir projects; cd projects
  git clone git@gitlab.com:halcyonblue/recipes.git
  git clone git@github.com:halcyon/arch-vm.git
  git clone git@github.com:halcyon/org.git
  cd ..
EOF
}

make_sbcl() {
    cp -r /vagrant/sbcl /home/${user}
    chown -R ${user}:${user} /home/${user}/sbcl
    cd /home/${user}/sbcl
    sudo -u smcleod makepkg --skipinteg
    aura --noconfirm --needed -U *.xz
}

install_stumpwm() {
sudo -iu smcleod zsh <<EOF
  curl -O https://beta.quicklisp.org/quicklisp.lisp
  sbcl --load /vagrant/install-quicklisp.lisp
  git clone https://github.com/stumpwm/stumpwm.git
  cd stumpwm
  autoconf
  ./configure
  make
EOF
  cd /home/${user}/stumpwm
  make install
}

install_packages() {
    typeset -U removals
    removals=("virtualbox-guest-utils-nox")

    typeset -U base
    base=("base-devel" "sbcl")

    typeset -U virtualbox_guest_additions
    virtualbox_guest_additions=("virtualbox-guest-utils"
                                "virtualbox-guest-modules-arch")

    typeset -U shell
    shell=("autojump" "tmux" "stow")

    typeset -U utilities
    utilities=("pass" "the_silver_searcher" "the_silver_searcher"
               "unzip" "emacs-nox" "git" "jdk8-openjdk")

    typeset -U xorg
    xorg=("xf86-input-libinput" "xorg-server" "xorg-server-utils" "xorg-apps"
          "xorg-xinit" "xclip" "rxvt-unicode" "ttf-ubuntu-font-family"
          "ttf-symbola" "noto-fonts" "firefox" "calibre")

    typeset -U aur
    aur=("aur-git" "leiningen-standalone" "tmate" "totp-cli" "dropbox"
         "dropbox-cli" "slack-desktop" "sococo" "kiwix-bin")

    aura --noconfirm -R ${removals}
    aura --noconfirm --needed -S ${base} ${virtualbox_guest_additions} ${shell} ${utilities} ${xorg}
    aura --noconfirm --needed -A ${aur}
}

configure_locale
configure_sound
add_user
setup_ssh
setup_gnupg
install_aura
install_packages
clone_repos
make_sbcl
install_stumpwm
systemctl enable vboxservice.service
secure_system
