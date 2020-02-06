#!/bin/bash

set -e
set -o pipefail

#	This script installs my basic setup for a debian laptop

export DEBIAN_FRONTEND=noninteractive

check_is_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "Please run as root."
		exit
	fi
}

# Choose a user account to use for this installation
get_user() {
	if [[ -z "${TARGET_USER-}" ]]; then
		mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
		# if there is only one option just use that user
		if [ "${#options[@]}" -eq "1" ]; then
			readonly TARGET_USER="${options[0]}"
			echo "Using user account: ${TARGET_USER}"
			return
		fi

		# iterate through the user options and print them
		PS3='command -v user account should be used? '

		select opt in "${options[@]}"; do
			readonly TARGET_USER=$opt
			break
		done
	fi
}

setup_sudo() {
    usermod -aG ${TARGET_USER} sudo
    groupadd -g 999 docker
    usermod -aG ${TARGET_USER} docker
}

# Install min packages
setup_sources_min() {
	apt update || true
	apt install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		dirmngr \
		gnupg2 \
		lsb-release \
        gnupg-agent \
        software-properties-common \
		--no-install-recommends
}

setup_sources() {
    # Add the Google Chrome distribution URI as a package source
	cat <<-EOF > /etc/apt/sources.list.d/google-chrome.list
	deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main
	EOF

    # Import the Google Chrome public key
	curl https://dl.google.com/linux/linux_signing_key.pub | apt-key add -

    # tlp: Advanced Linux Power Management
	cat <<-EOF > /etc/apt/sources.list.d/tlp.list
	# tlp: Advanced Linux Power Management
	# http://linrunner.de/en/tlp/docs/tlp-linux-advanced-power-management.html
	deb http://repo.linrunner.de/debian sid main
	EOF

    # add the tlp apt-repo gpg key
	apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 6B283E95745A6D903009F7CA641EED65CD4E8809

    # Import keyring from i3
    /usr/lib/apt/apt-helper download-file https://debian.sur5r.net/i3/pool/main/s/sur5r-keyring/sur5r-keyring_2019.02.01_all.deb /tmp/keyring.deb SHA256:176af52de1a976f103f9809920d80d02411ac5e763f695327de9fa6aff23f416
    dpkg -i /tmp/keyring.deb

    # Add the i3 package source
    echo "deb https://debian.sur5r.net/i3/ $(grep '^DISTRIB_CODENAME=' /etc/lsb-release | cut -f2 -d=) universe" >> /etc/apt/sources.list.d/sur5r-i3.list

    # Add public key docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-key fingerprint 0EBFCD88

    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

}

base_min() {
	apt update || true
	apt -y upgrade

	apt install -y \
		adduser \
		automake \
		bc \
		bzip2 \
		ca-certificates \
		coreutils \
		curl \
		dnsutils \
		file \
		findutils \
		gcc \
		git \
		gnupg \
		gnupg2 \
		grep \
		gzip \
		hostname \
		indent \
		iptables \
		jq \
        yq \
		less \
		libc6-dev \
		locales \
		lsof \
		make \
		mount \
		net-tools \
		policykit-1 \
		silversearcher-ag \
		ssh \
        sshpass \
		strace \
		sudo \
		tar \
		tree \
		tzdata \
		unzip \
		vim \
		xz-utils \
		zip \
        docker-ce \
        docker-ce-cli \
        containerd.io \
		--no-install-recommends

	apt autoremove
	apt autoclean
	apt clean

	install_scripts
}

# installs base packages
# the utter bare minimal shit
base() {
	base_min;

    apt-get remove docker docker-engine docker.io containerd runc

	apt update || true
	apt -y upgrade

	apt install -y \
		apparmor \
		bridge-utils \
		cgroupfs-mount \
		fwupd \
		fwupdate \
		gnupg-agent \
		google-cloud-sdk \
        awscli \
		iwd \
		libapparmor-dev \
		libimobiledevice6 \
		libltdl-dev \
		libpam-systemd \
		libseccomp-dev \
		pinentry-curses \
		scdaemon \
		systemd \
        meld \
		indicator-sound-switcher \
		fonts-firacode \
		--no-install-recommends

	setup_sudo

	apt autoremove
	apt autoclean
	apt clean
}

# install custom scripts/binaries
install_scripts() {
	# install speedtest
	curl -sSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py  > /usr/local/bin/speedtest
	chmod +x /usr/local/bin/speedtest

    # install terraform
    curl -sSL https://releases.hashicorp.com/terraform/0.12.20/terraform_0.12.20_linux_amd64.zip -o /tmp/terraform.zip
    unzip -d /usr/local/bin/ /tmp/terraform.zip
    chmod +x /usr/local/bin/terraform

}

# install stuff for i3 window manager
install_wmapps() {
	apt update || true
	apt install -y \
		bluez \
		bluez-firmware \
		feh \
		i3 \
		i3lock \
		i3status \
        i3-wm \
		pulseaudio \
		pulseaudio-module-bluetooth \
		pulsemixer \
		scrot \
		suckless-tools \
		rxvt-unicode-256color \
		usbmuxd \
		xclip \
		xcompmgr \
        pkg-config \
        libxcb \
        libxcb-util \
        libpam-dev \
        libcairo-dev \
        libxcb-xinerama \
        libev \
        libx11-dev \
        libx11-xcb-dev \
        libxkbcommon \
        libxkbcommon-x11 \
        libconfuse-dev \
        thunar \
		--no-install-recommends

	sed -i 's|user-session.*|user-session=i3|g' /etc/lightdm/lightdm.conf.d/70-linuxmint.conf
	dpkg-reconfigure lightdm

}

get_dotfiles() {
	# create subshell
	(
	cd "$HOME"

	if [[ ! -d "${HOME}/dotfiles" ]]; then
		# install dotfiles from repo
		git clone git@github.com:caiotedim/dotfiles.git "${HOME}/dotfiles"
	fi

	cd "${HOME}/dotfiles"

	# set the correct origin
	git remote set-url origin git@github.com:caiotedim/dotfiles.git

	# installs all the things
	make

	# enable dbus for the user session
	# systemctl --user enable dbus.socket

	sudo systemctl enable "i3lock@${TARGET_USER}"

	cd "$HOME"
	mkdir -p ~/Pictures/Screenshots
	)

	install_vim;
}

# install/update golang from source
install_golang() {
	export GO_VERSION
	GO_VERSION=$(curl -sSL "https://golang.org/VERSION?m=text")
	export GO_SRC=/usr/local/go

	# if we are passing the version
	if [[ -n "$1" ]]; then
		GO_VERSION=$1
	fi

	# purge old src
	if [[ -d "$GO_SRC" ]]; then
		sudo rm -rf "$GO_SRC"
		#sudo rm -rf "$GOPATH"
	fi

	GO_VERSION=${GO_VERSION#go}

	# subshell
	(
	kernel=$(uname -s | tr '[:upper:]' '[:lower:]')
	curl -sSL "https://storage.googleapis.com/golang/go${GO_VERSION}.${kernel}-amd64.tar.gz" | sudo tar -v -C /usr/local -xz
	local user="$USER"
	# rebuild stdlib for faster builds
	sudo chown -R "${user}" /usr/local/go/pkg
	CGO_ENABLED=0 go install -a -installsuffix cgo std
	)

	# get commandline tools
	(
	set -x
	set +e
	go get golang.org/x/lint/golint
	go get golang.org/x/tools/cmd/cover
	go get golang.org/x/tools/cmd/gopls
	go get golang.org/x/review/git-codereview
	go get golang.org/x/tools/cmd/goimports
	go get golang.org/x/tools/cmd/gorename
	go get golang.org/x/tools/cmd/guru

	# Tools for vimgo.
	go get github.com/jstemmer/gotags
	go get github.com/nsf/gocode
	go get github.com/rogpeppe/godef
    )

}

usage() {
	echo -e "install.sh\\n\\tThis script installs my basic setup for a linux mint laptop\\n"
	echo "Usage:"
	echo "  base                                - setup sources & install base pkgs"
	echo "  basemin                             - setup sources & install base min pkgs"
	echo "  wm                                  - install window manager/desktop pkgs"
	echo "  dotfiles                            - get dotfiles"
	echo "  vim                                 - install vim specific dotfiles"
	echo "  golang                              - install golang and packages"
	echo "  scripts                             - install scripts"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "base" ]]; then
		check_is_sudo
		get_user

		# setup /etc/apt/sources.list
		setup_sources

		base
	elif [[ $cmd == "basemin" ]]; then
		check_is_sudo
		get_user

		# setup /etc/apt/sources.list
		setup_sources_min

		base_min
	elif [[ $cmd == "wm" ]]; then
		check_is_sudo

		install_wmapps
	elif [[ $cmd == "dotfiles" ]]; then
		get_user
		get_dotfiles
	elif [[ $cmd == "vim" ]]; then
		install_vim
	elif [[ $cmd == "golang" ]]; then
		install_golang "$2"
	elif [[ $cmd == "scripts" ]]; then
		check_is_sudo
		install_scripts
	else
		usage
	fi
}

main "$@"
