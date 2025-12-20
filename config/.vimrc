"*******************************************************************************
"* # HISTORY
" 2025/08/26 - DPENG
" - Just discovered `set mouse=a` for mouse mode!
"   - Added ttymouse setting so can use "Mouse reporting" with TMUX to resize
"     VIM split panes.
" - Align Mac vs Linux .vimrc
" - Adding someone's setting for using `absolute` number for insert mode and
"   `relative` number for normal mode.
"
" 2025/08/27 - DPENG
" - Block relative number (rnu). Too distracting and doesn't help with debugging
"   when programs fail and lists line number.
"
" 2025/12/17 - DPENG
" - Block mouse reporting. Interferes too much with how I was using copy and
"   paste between tmux panes.
"
"
"*******************************************************************************


"* Enables VIM "advanced" functions if not enabled before.
if &compatible
    set nocompatible
endif

"******** EDITOR SETTINGS
"set modeline                      "* Allows file specific "vimrc" settings.
"set modeliens=5                   "* Specifies how many lines for settings.
"set mouse=                        "* FOR RPI. ("normal" mouse behavior in Raspberry Pi)
set ignorecase                    "* Ignores case searches.
set smartcase                     "* Become case sensitive search if you type uppercase characters
set autochdir                     "* Change current working directory to opened/selected file (like in NEdit)
"set lines=35 columns=100          "* (.gvimrc) Sets window size.
set showcmd                       "* (Repeat)Display incomplete commands.
set visualbell                    "* Error bells are displayed visually.
set wildmenu                      "* Show autocomplete menus.
set backspace=indent,eol,start    "* Allows backspace to delete autoindent, "join lines" delete, and backspace over start of insert.
"set smartindent                   "* Set smartindent for"auto" indenting w/programming languages
set autoindent                    "* Allows next line to automatically indent aligned to current line.
set incsearch                     "* Do incremental searching
set hls                           "* Highlight search results
set shiftwidth=4                  "* Spaces for autoindents
set tabstop=4                     "* Number of spaces a tab counts for
set expandtab                     "* Expands tabs into spaces
"set smarttab                      "* Smart tab handling for indenting




"******** DISPLAY SETTINGS
set number                         "* Shows line numbers
set title                          "* Show file in titlebar
highlight LineNr ctermfg=red       "* Changes VIM line number from yellow to red (more legible in terminal; can use any color aside from red)
set scrolloff=1                    "* 1 lines above/below cursor when scrolling

"colorscheme=peachpuff              "* neovim with solarized light (ish)
"colorscheme=morning                "* neovim with solarized light (ish)


"******** Status line
set laststatus=2
set statusline=
set statusline+=%-3.3n\                      " buffer number
set statusline+=%f\                          " filename
set statusline+=%h%m%r%w                     " status flags
set statusline+=\[%{strlen(&ft)?&ft:'none'}] " file type
set statusline+=%=                           " right align remainder
set statusline+=0x%-8B                       " character value
set statusline+=%-14(%l,%c%V%)               " line, character
set statusline+=%<%P  

"* Setting default font (OS specific)
if has('win32')
    set gfn=Courier_New:h10:cANSI
else
    let os = substitute(system('uname'),"\n","","")

    if os == "SunOS"
        set gfn=-adobe-courier-medium-r-normal-*-*-120-*-*-m-*-iso8859-1
    endif
endif



"******** KEYBOARD SHORTCUT SETTINGS
"* Uses <Tab> key to show menu of options
set wildchar=<Tab> wildmenu wildmode=longest,full
"set wildmode=longest,full
"
"* Map <F5> to reload/refresh opened file
nmap <f5> :e!<CR> G<CR>

"******** To save, press ctrl-s.  (Possible when running with GUI, ie: gvim)
nmap <c-s> :w<CR>
imap <c-s> <Esc>:w<CR>a

"******** Map <F2> to go to previous buffer
nmap <f2> :bp<CR>
"******** Map <F3> to go to next buffer
nmap <f3> :bn<CR>
"******** Map <F4> to close current buffer (remember "ALT-F4")
nmap <f4> :bd<CR>

"******** Ease of use to navigate between tabs.  "Tabs" may only be in Windows "gVIM"
"* <Alt-j> to move to left tab
"noremap <A-j> gt
"* <Alt-k> to move to right tab
"noremap <A-k> gT



"******** MISCELLANEOUS SETTINGS

"******** Folding and ease of use for folding.
"* 'Folds' colde by method of correct indents
"set foldmethod=indent

"*Remaps <space> to 'a'lternate b/n opening & closing a fold repectively ('za')
"* 'z-o' = fold open
"* 'z-c' = fold close
"noremap <space> za


"* Hightlight spaces and tabs
"* Highlight redundant whitespaces and tabs. Only shows trailing whitespace :)
highlight RedundantSpaces ctermbg=red
match RedundantSpaces /\s\+$/


"* Ignores whitespace in vimdiff
set diffopt+=iwhite


"* For older VIM , *.md files assigned to "modula2":
"  /usr/share/vim/vim74/filetype.vim (I found "markdown" in vim74. Older vim7x
"  doesn't list "markdown".
"  This overwrite the default setting. Seems not needed for "new" vim.
"autocmd BufNewFile,BufRead *.md set filetype=m


""* Mouse reporting
""  Google mentions allows to move cursor, select text (visual mode), scroll,
""  resize window.
"set mouse=a
""* TMUX: Added in conjunction with "Mouse reporting" so I can use mouse to
""  resize VIM split panes.
"set ttymouse=xterm2


"" Set up automatically switching between absolute & relative numbers depending
"" on insert/normal mode.
"" Normal mode: relative number
"" Insert mode: absolute number
""* https://jeffkreeftmeijer.com/vim-number/
""
"augroup numbertoggle
"  autocmd!
"  autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | set rnu   | endif
"  autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | set nornu | endif
"augroup END



