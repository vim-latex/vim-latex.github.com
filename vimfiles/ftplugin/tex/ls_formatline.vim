" ==============================================================================
" Author: Carl Mueller
" 		  (incorporated into latex-suite by Srinath Avadhanula)
" Last Change: Sun Nov 10 05:00 PM 2002 PST
" Desciption:
" ============================================================================== 

if &tw > 0
	let b:tw = &tw
else
	let b:tw = 79
endif
" The following is necessary for TexFormatLine() and TexFill()
set tw=0

"  With this map, <Space> will split up a long line, keeping the dollar
"  signs together (see the next function, TexFormatLine).
inoremap <buffer> <Space> <Space><Esc>:call <SID>TexFill(b:tw)<CR>a
function! s:TexFill(width)
    if col(".") > a:width
	exe "normal! a##\<Esc>"
	call <SID>TexFormatLine(a:width)
	exe "normal! ?##\<CR>2s\<Esc>"
    endif
endfunction

function! s:TexFormatLine(width)
    let first = strpart(getline(line(".")),0,1)
    normal! $
    let length = col(".")
    let go = 1
    while length > a:width+2 && go
	let between = 0
	let string = strpart(getline(line(".")),0,a:width)
	" Count the dollar signs
        let number_of_dollars = 0
	let evendollars = 1
	let counter = 0
	while counter <= a:width-1
	    if string[counter] == '$' && string[counter-1] != '\'  " Skip \$.
	       let evendollars = 1 - evendollars
	       let number_of_dollars = number_of_dollars + 1
	    endif
	    let counter = counter + 1
	endwhile
	" Get ready to split the line.
	exe "normal! " . (a:width + 1) . "|"
	if evendollars
	" Then you are not between dollars.
	   exe "normal! ?\\$\\| \<CR>W"
	else
	" Then you are between dollars.
	    normal! F$
	    if col(".") == 1 || strpart(getline(line(".")),col(".")-1,1) != "$"
	       let go = 0
	    endif
	endif
	if first == '$' && number_of_dollars == 1
	    let go = 0
	else
	    exe "normal! i\<CR>\<Esc>$"
	    let first = strpart(getline(line(".")),0,1)
	endif
	let length = col(".")
    endwhile
endfunction
