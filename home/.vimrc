" Vim 推奨の defaults.vim を読む (macOS の /usr/share/vim/vimrc が skip_defaults_vim を立てているため解除する)
" ttimeoutlen=100 で Esc の遅延をなくし、incsearch・scrolloff・前回カーソル位置の復元を有効にする
unlet! skip_defaults_vim
source $VIMRUNTIME/defaults.vim
" defaults.vim が有効にするマウスは使わず、端末と tmux の選択操作を残す
set mouse=

" 改行コードの自動認識
set fileformats=unix,dos,mac

set tabstop=2
set textwidth=0
set shiftwidth=2
set expandtab

set number
set smartindent
set showmatch
set showmode
set nobackup
set noswapfile
set hlsearch
set ignorecase
set smartcase

" シンタックスチェック機能
nmap ,l :call SyntaxCheck()<CR>
nmap ,e :call ExecuteCode()<CR>

function SyntaxCheck()
  execute ":w"
  if ("ruby" == &filetype)
    echo system("ruby -c ".bufname(""))
  elseif ("yaml" == &filetype)
    echo system('ruby -ryaml -e "begin;YAML::load(open(\"'.bufname("").'\",\"r\").read); puts \"ok\"; rescue ArgumentError => e; puts e; end"')
  end
endfunction

function ExecuteCode()
  execute ":w"
  if ("ruby" == &filetype)
    execute ":! ruby %"
  end
endfunction

" space可視化の呪文 (ref. http://d.hatena.ne.jp/potappo2/20061107/1162862536)
if has("syntax")
    function! ActivateInvisibleIndicator()
        syntax match InvisibleJISX0208Space "　" display containedin=ALL
        highlight InvisibleJISX0208Space term=underline ctermbg=Blue guibg=Blue
        syntax match InvisibleTrailedSpace "[ \t]\+$" display containedin=ALL
        highlight InvisibleTrailedSpace term=underline ctermbg=Red guibg=Red
        syntax match InvisibleTab "\t" display containedin=ALL
        highlight InvisibleTab term=underline ctermbg=Cyan guibg=Cyan
    endf

    augroup invisible
        autocmd! invisible
        autocmd BufNew,BufRead * call ActivateInvisibleIndicator()
    augroup END
endif
