install: zsh vim git xfiles tmux

zsh:
	rm -rf ~/.zshrc ~/.zshalias
	ln -s `pwd`/zshrc ~/.zshrc
	ln -s `pwd`/zshalias ~/.zshalias

git:
	rm -rf ~/.gitconfig
	ln -s `pwd`/gitconfig ~/.gitconfig

vim:
	rm -rf ~/.vimrc ~/.vim
	ln -s `pwd`/vimrc ~/.vimrc
	ln -s `pwd`/vim ~/.vim

xfiles:
	rm -rf ~/.xbindkeysrc ~/.xinitrc ~/.xmodmaprc ~/.Xdefaults
	ln -s `pwd`/xbindkeysrc ~/.xbindkeysrc
	ln -s `pwd`/xmodmaprc ~/.xmodmaprc
	ln -s `pwd`/Xdefaults ~/.Xdefaults
	ln -s `pwd`/xinitrc ~/.xinitrc

tmux:
	rm -rf ~/.tmux.conf
	ln -s `pwd`/tmux.conf ~/.tmux.conf
