install: install-zsh install-vim install-git install-xfiles install-tmux \
  		 install-hg install-fontconfig install-dunst install-i3 install-nvim \
		 install-aerospace install-wezterm

bootstrap-system:
	bootstrap/system

bootstrap-elixir:
	bootstrap/elixir

bootstrap-rust:
	bootstrap/rust

bootstrap-zig:
	bootstrap/zig

bootstrap-wezterm:
	bootstrap/wezterm

bootstrap-ghostty:
	bootstrap/ghostty

bootstrap-homebrew:
	bootstrap/homebrew

install-zsh:
	rm -rf ~/.zshrc ~/.zshalias
	ln -s `pwd`/zsh/zshrc ~/.zshrc
	ln -s `pwd`/zsh/zshalias ~/.zshalias

install-git:
	rm -rf ~/.gitconfig
	ln -s `pwd`/gitconfig ~/.gitconfig

install-vim:
	rm -rf ~/.vimrc ~/.vim
	ln -s `pwd`/vim ~/.vim
	ln -s `pwd`/vim/vimrc ~/.vimrc

install-nvim: nvim-config
	bootstrap/nvim

nvim-config:
	rm -rf ~/.config/nvim
	ln -s `pwd`/nvim ~/.config/nvim

install-xfiles:
	rm -rf ~/.xbindkeysrc ~/.xinitrc ~/.xmodmaprc ~/.Xdefaults ~/.urxvt
	ln -s `pwd`/xbindkeysrc ~/.xbindkeysrc
	ln -s `pwd`/xmodmaprc ~/.xmodmaprc
	ln -s `pwd`/Xdefaults ~/.Xdefaults
	ln -s `pwd`/xinitrc ~/.xinitrc
	ln -s `pwd`/urxvt ~/.urxvt

install-tmux:
	rm -rf ~/.tmux.conf
	ln -s `pwd`/tmux/tmux.conf ~/.tmux.conf
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm || bash -c "pushd ~/.tmux/plugins/tpm && git pull && popd"
	rm -rf ~/.local/bin/tmux-sessionizer
	ln -s `pwd`/tmux/tmux-sessionizer ~/.local/bin/tmux-sessionizer
	rm -rf ~/.local/bin/tmux-switch
	ln -s `pwd`/tmux/tmux-switch ~/.local/bin/tmux-switch

install-hg:
	rm -rf ~/.hgrc
	ln -s `pwd`/hgrc ~/.hgrc

install-fontconfig:
	rm -rf ~/.config/fontconfig
	ln -s `pwd`/fontconfig ~/.config/fontconfig

install-i3:
	rm -rf ~/.i3
	ln -s `pwd`/i3 ~/.i3

install-dunst:
	rm -rf ~/.config/dunst
	ln -s `pwd`/dunst ~/.config/dunst

install-alacritty:
	rm -rf ~/.config/alacritty.yml ~/.config/alacritty.toml
	ln -s `pwd`/alacritty.toml ~/.config/alacritty.toml

install-wezterm:
	rm -rf ~/.wezterm.lua
	rm -f ~/.config/wezterm
	ln -s `pwd`/wezterm.lua ~/.wezterm.lua
	ln -s `pwd`/wezterm ~/.config/wezterm

install-aerospace:
	rm -rf ~/.aerospace.toml
	ln -s `pwd`/aerospace.toml ~/.aerospace.toml

install-mac-kblayouts:
	cp -rf mac/layouts/* ~/Library/Keyboard\ Layouts/.

install-ghostty:
	rm -rf ~/.config/ghostty
	ln -s `pwd`/ghostty ~/.config/ghostty
