set nocompatible

so ~/.vim/plugins.vim


"------------Plugins-----------"
let g:ctrlp_custom_ignore = 'node_modules\DS_STORE\|git'
let g:ctrlp_match_window = 'top,order:ttb,min:1,max:30,results:30'

let NERDTreeHijackNetrw = 0

"------------General-----------"
set backspace=indent,eol,start              "Make backspace behave like every other editor.
let mapleader = ',' 						"The default is \, but a comma is much better.




"------------Visuals-----------"

syntax enable
colorscheme dracula

"-------Split Management-------"
set splitbelow 								"Make splits default to below...
set splitright								"And to the right. This feels more natural.

"We'll set simpler mappings to switch between splits.
nmap <C-J> <C-W><C-J>
nmap <C-K> <C-W><C-K>
nmap <C-H> <C-W><C-H>
nmap <C-L> <C-W><C-L>





"-----------Mappings-----------"

"Make it easy to edit the Vimrc file.
nmap <Leader>ev :tabedit $MYVIMRC<cr>

"Add simple highlight removal.
nmap <Leader><space> :nohlsearch<cr>

"Make NERDTree easier to toggle.
nmap <Leader><1> :NERDTreeToggle<cr>

"Select All
nmap <Leader>a ggVG<cr>
"nmap <C-A> ggVG<cr>



"---------Auto-Commands--------"

"Automatically source the Vimrc file on save.

augroup autosourcing
	autocmd!
	autocmd BufWritePost .vimrc source %
augroup END
