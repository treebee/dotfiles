install: install-zsh install-vim install-git install-xfiles install-tmux

install-zsh:
	rm -rf ~/.zshrc ~/.zshalias
	ln -s `pwd`/zshrc ~/.zshrc
	ln -s `pwd`/zshalias ~/.zshalias

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
