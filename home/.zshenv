export EDITOR=vim
export LANG=en_US.UTF-8
export PATH=$HOME/bin:/usr/local/bin:$PATH

if [ -x "`which go`" ]; then
  export GOPATH=$HOME/go
  export GOROOT=`go env GOROOT`
  export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
fi
