install: install-zsh install-vim install-git install-xfiles install-tmux \
  		 install-hg install-fontconfig install-subtle

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
	ln -s ~/vim/vimrc ~/.vimrc

install-xfiles:
	rm -rf ~/.xbindkeysrc ~/.xinitrc ~/.xmodmaprc ~/.Xdefaults
	ln -s `pwd`/xbindkeysrc ~/.xbindkeysrc
	ln -s `pwd`/xmodmaprc ~/.xmodmaprc
	ln -s `pwd`/Xdefaults ~/.Xdefaults
	ln -s `pwd`/xinitrc ~/.xinitrc

install-tmux:
	rm -rf ~/.tmux.conf
	ln -s `pwd`/tmux.conf ~/.tmux.conf

install-hg:
	rm -rf ~/.hgrc
	ln -s `pwd`/hgrc ~/.hgrc

install-fontconfig:
	rm -rf ~/.config/fontconfig
	ln -s `pwd`/fontconfig ~/.config/fontconfig

install-subtle:
	rm -rf ~/.config/subtle
	ln -s `pwd`/subtle ~/.config/subtle
