install: install-zsh install-vim install-git install-xfiles install-tmux \
  		 install-hg install-fontconfig install-dunst install-i3 install-nvim

install-zsh:
	rm -rf ~/.zshrc ~/.zshalias
	rm -f ~/.oh-my-zsh
	ln -s `pwd`/zsh/zshrc ~/.zshrc
	ln -s `pwd`/zsh/zshalias ~/.zshalias
	ln -s `pwd`/oh-my-zsh ~/.oh-my-zsh

install-git:
	rm -rf ~/.gitconfig
	ln -s `pwd`/gitconfig ~/.gitconfig

install-vim:
	rm -rf ~/.vimrc ~/.vim
	ln -s `pwd`/vim ~/.vim
	ln -s `pwd`/vim/vimrc ~/.vimrc

install-nvim:
	rm -rf ${XDG_CONFIG_HOME}/nvim
	ln -s `pwd`/nvim ${XDG_CONFIG_HOME}/nvim

install-xfiles:
	rm -rf ~/.xbindkeysrc ~/.xinitrc ~/.xmodmaprc ~/.Xdefaults ~/.urxvt
	ln -s `pwd`/xbindkeysrc ~/.xbindkeysrc
	ln -s `pwd`/xmodmaprc ~/.xmodmaprc
	ln -s `pwd`/Xdefaults ~/.Xdefaults
	ln -s `pwd`/xinitrc ~/.xinitrc
	ln -s `pwd`/urxvt ~/.urxvt

install-tmux:
	rm -rf ~/.tmux.conf
	ln -s `pwd`/tmux.conf ~/.tmux.conf

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
