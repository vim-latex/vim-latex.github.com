"        File: imaps.vim
"     Authors: Srinath Avadhanula <srinath AT fastmail.fm>
"              Benji Fisher <benji AT member.AMS.org>
"              
"         WWW: http://cvs.sourceforge.net/cgi-bin/viewcvs.cgi/vim-latex/vimfiles/plugin/imaps.vim?only_with_tag=MAIN
"
" Description: insert mode template expander with cursor placement
"              while preserving filetype indentation.
"
" Last Change: Sat Dec 14 02:00 AM 2002 PST
" 
" Documentation: {{{
"
" Motivation:
" this script provides a way to generate insert mode mappings which do not
" suffer from some of the problem of mappings and abbreviations while allowing
" cursor placement after the expansion. It can alternatively be thought of as
" a template expander. 
"
" Consider an example. If you do
"
" imap lhs something
"
" then a mapping is set up. However, there will be the following problems:
" 1. the 'ttimeout' option will generally limit how easily you can type the
"    lhs. if you type the left hand side too slowly, then the mapping will not
"    be activated.
" 2. if you mistype one of the letters of the lhs, then the mapping is
"    deactivated as soon as you backspace to correct the mistake.
"
" If, in order to take care of the above problems, you do instead
"
" iab lhs something
"
" then the timeout problem is solved and so is the problem of mistyping.
" however, abbreviations are only expanded after typing a non-word character.
" which causes problems of cursor placement after the expansion and invariably
" spurious spaces are inserted.
" 
" Usage Example:
" this script attempts to solve all these problems by providing an emulation
" of imaps wchich does not suffer from its attendant problems. Because maps
" are activated without having to press additional characters, therefore
" cursor placement is possible. furthermore, file-type specific indentation is
" preserved, because the rhs is expanded as if the rhs is typed in literally
" by the user.
"  
" The script already provides some default mappings. each "mapping" is of the
" form:
"
" call Tex_IMAP (lhs, rhs, ft)
" 
" Some characters in the RHS have special meaning which help in cursor
" placement.
"
" Example One:
"
" 	call Tex_IMAP ("bit`", "\\begin{itemize}\<cr>\\item <++>\<cr>\\end{itemize}<++>", "tex")
" 
" This effectively sets up the map for "bit`" whenever you edit a latex file.
" When you type in this sequence of letters, the following text is inserted:
" 
" \begin{itemize}
" \item *
" \end{itemize}<++>
"
" where * shows the cursor position. The cursor position after inserting the
" text is decided by the position of the first "place-holder". Place holders
" are special characters which decide cursor placement and movement. In the
" example above, the place holder characters are <+ and +>. After you have typed
" in the item, press <C-j> and you will be taken to the next set of <++>'s.
" Therefore by placing the <++> characters appropriately, you can minimize the
" use of movement keys.
"
" NOTE: Set g:Imap_UsePlaceHolders to 0 to disable placeholders altogether.
" Set 
" 	g:Imap_PlaceHolderStart and g:Imap_PlaceHolderEnd
" to something else if you want different place holder characters.
" Also, b:Imap_PlaceHolderStart and b:Imap_PlaceHolderEnd override the values
" of g:Imap_PlaceHolderStart and g:Imap_PlaceHolderEnd respectively. This is
" useful for setting buffer specific place hoders.
" 
" Example Two:
" You can use the <C-r> command to insert dynamic elements such as dates.
"	call Tex_IMAP ('date`', "\<c-r>=strftime('%b %d %Y')\<cr>", '')
"
" sets up the map for date` to insert the current date.
"
"--------------------------------------%<--------------------------------------
" Bonus: This script also provides a command Snip which puts tearoff strings,
" '----%<----' above and below the visually selected range of lines. The
" length of the string is chosen to be equal to the longest line in the range.
"--------------------------------------%<--------------------------------------
" }}}

" ==============================================================================
" Script variables
" ==============================================================================
" {{{
" A lot of back-spaces, to be used by IMAP().  If needed, more will be added
" automatically.
let s:backsp = substitute("0123456789", '\d', "\<bs>", 'g')
" s:LHS_{ft}_{char} will be generated automatically.  It will look like
" s:LHS_tex_o = 'fo\|foo\|boo' and contain all mapped sequences ending in "o".
" s:Map_{ft}_{lhs} will be generated automatically.  It will look like
" s:Map_c_foo = 'for(<++>; <++>; <++>)', the mapping for "foo".
"
" }}}

" ==============================================================================
" functions for easy insert mode mappings.
" ==============================================================================
" IMAP: Adds a "fake" insert mode mapping. {{{
"       For example, doing
"           Tex_IMAP('abc', 'def' ft) 
"       will mean that if the letters abc are pressed in insert mode, then
"       they will be replaced by def. If ft != '', then the "mapping" will be
"       specific to the files of type ft. 
"
"       Using IMAP has a few advantages over simply doing:
"           imap abc def
"       1. with imap, if you begin typing abc, the cursor will not advance and
"          long as there is a possible completion, the letters a, b, c will be
"          displayed on on top of the other. using this function avoids that.
"       2. with imap, if a backspace or arrow key is pressed before completing
"          the word, then the mapping is lost. this function allows movement. 
"          (this ofcourse means that this function is only limited to
"          left-hand-sides which do not have movement keys or unprintable
"          characters)
"       It works by only mapping the last character of the left-hand side.
"       when this character is typed in, then a reverse lookup is done and if
"       the previous characters consititute the left hand side of the mapping,
"       the previously typed characters and erased and the right hand side is
"       inserted
function! IMAP(ft, lhs, ...)
	let lastLHSChar = a:lhs[strlen(a:lhs)-1]
	" Make sure that s:backsp is long enough:
	while strlen(s:backsp) < strlen(a:lhs)
		let s:backsp = s:backsp . s:backsp
	endwhile
	" Add a:lhs to the list of left-hand sides that end with lastLHSChar:
	if !exists("s:LHS_" . a:ft . "_" . s:Hash(lastLHSChar))
		let s:LHS_{a:ft}_{s:Hash(lastLHSChar)} = escape(a:lhs, '\')
	else
		let s:LHS_{a:ft}_{s:Hash(lastLHSChar)} = escape(a:lhs, "\\") . '\|' .
					\ s:LHS_{a:ft}_{s:Hash(lastLHSChar)}
	endif
	" Build up the right-hand side:
	let rhs = ""
	let phs = s:PlaceHolderStart()
	let phe = s:PlaceHolderEnd()
	let i = 1   " counter for arguments
	let template = 0    " flag:  is the current argument a <+template+> ?
	while i <= a:0
		if template
			let rhs = rhs . phs . a:{i} . phe
		else
			let rhs = rhs . a:{i}
		endif
		let i = i+1
		let template = !template
	endwhile
	let s:Map_{a:ft}_{s:Hash(a:lhs)} = rhs

	" map only the last character of the left-hand side.
	if lastLHSChar == ' '
		let lastLHSChar = '<space>'
	end
	exe 'inoremap <silent>' escape(lastLHSChar, '|')
				\ '<C-r>=<SID>NewLookupCharacter("' . escape(lastLHSChar, '\|') .
				\ '")<CR>'
endfunction

" }}}
" Tex_IMAP: This is the old version of IMAP which used to take 3 arguments. {{{
"           It has been changed in order to retain backwards compatibility (of
"           sorts) while still using the new IMAP
" It could also be used for convinience in places where specifying multiple
" arguments might be tedious.
"
" Ex:
"
" call Tex_IMAP('foo', 'ba<++>bar', '', '<+', '+>')
"
" The last 2 optional arguments specify the placeholder characters in the rhs.
" See s:PlaceHolderStart() and s:PlaceHolderEnd for how they are chosen if the
" the optional arguments are unspecified.
function! Tex_IMAP(lhs, rhs, ft, ...)

	if a:0 > 0
		let phs = a:1
		let phe = a:2
	else
		" Tex_IMAP is only concerned with mappings which latex-suite itself
		" generates. This means that we do not use the g:Imap_PlaceHolder*
		" settings.
		let phs = '<+'
		let phe = '+>'
	endif

	" break up the rhs into multiple chunks 
	let remainingString = a:rhs
	let callString = 'call IMAP(a:ft, a:lhs, arg_1'

	let i = 1
	while remainingString != ''
		let firstPart = matchstr(remainingString, '^.\{-}\ze\('.phs.'\|$\)')
		let secondPart = matchstr(remainingString, 
								 \ phs.'\zs.\{-}\ze'.phe,
								 \ strlen(firstPart))
		let arg_{i} = firstPart
		" we have already appended one argument. Do this only from next time
		" on.
		if i > 1
			let callString = callString.', arg_'.i
		endif

		" if firstPart is smaller than the total string, then there is a
		" placeholder. Therefore append the placeholder as an argument
		if strlen(firstPart) < strlen(remainingString)
			let i = i + 1

			let arg_{i} = secondPart
			let callString = callString.', arg_'.i
		endif

		" find out the part remaining.
		let remainingString = strpart(remainingString, 
									  \ strlen(firstPart) +
									  \ strlen(secondPart) +
									  \ strlen(phs) + strlen(phe))

		if i >= 20
			echomsg 'getting more than 20 placeholders!'
			echomsg 'input rhs = '.a:rhs
		endif

		let i = i + 1
	endwhile

	" Finally, we end up with a string like:
	" 'call IMAP(a:ft, a:lhs, arg_1, arg_2, arg_3)'
	let callString = callString.')'

	echomsg callString
	exec callString
endfunction

" }}}
" LookupCharacter: inserts mapping corresponding to this character {{{
"
" This function performs a reverse lookup when this character is typed in. It
" loops over all the possible left-hand side variables ending in this
" character and then if a possible match exists, erases the left-hand side
" and inserts the right-hand side instead.
function! s:NewLookupCharacter(char)
	let charHash = s:Hash(a:char)

	if exists("s:LHS_" . &ft . "_" . charHash)
		let ft = &ft
	elseif exists("s:LHS__" . charHash)
		let ft = ""
	else
		return a:char
	endif
	" Find the longest left-hand side that matches the line so far.
	" Use '\V' (very no-magic) so that only '\' is special, and it was already
	" escaped when building up s:LHS_{ft}_{charHash} .
	let text = strpart(getline("."), 0, col(".")-1) . a:char
	" matchstr() returns the longest match. This automatically ensures that
	" the longest LHS is used for the mapping.
	let lhs = matchstr(text, '\V\(' . s:LHS_{ft}_{charHash} . '\)\$')
	if strlen(lhs) == 0
		return a:char
	endif
	" enough back-spaces to erase the left-hand side; -1 for the last
	" character typed:
	let bs = substitute(strpart(lhs, 1), ".", "\<bs>", "g")
	" Execute this string to get to the start of the replacement text:
	let mark = line(".") . "norm!" . (virtcol(".") - strlen(lhs) + 1) . "|"
	return bs . IMAP_PutTextWithMovement(s:Map_{ft}_{s:Hash(lhs)}, mark)
endfunction

" Old version:
function! <SID>LookupCharacter(char)
	let charHash = char2nr(a:char)

	if !exists('s:charLens_'.&ft.'_'.charHash)
		\ && !exists('s:charLens__'.charHash)
		return a:char
	end

	let k = 1
	while k <= 2
		" first check the filetype specific mappings and then the general
		" purpose mappings.
		if k == 1
			let ft = &ft
		else
			let ft = ''
		end

		" get the lengths of the left-hand side mappings which end in this
		" character. if no mappings ended in this character, then continue... 
		if !exists('s:charLens_'.ft.'_'.charHash)
			let k = k + 1
			continue
		end

		exe 'let lens = s:charLens_'.ft.'_'.charHash

		let i = 1
		while 1
			" get the i^th length. 
			let numchars = s:Strntok(lens, ',', i)
			" if there are no more lengths, then skip to the next outer while
			" loop.
			if numchars == ''
				break
			end

			if col('.') < numchars
				let i = i + 1
				continue
			end
			
			" get the corresponding text from before the text. append the present
			" char to complete the (possible) LHS
			let text = strpart(getline('.'), col('.') - numchars, numchars - 1).a:char
			let lhsHash = 's:Map_'.ft.'_'.substitute(text, '\(\W\)', '\="_".char2nr(submatch(1))."_"', 'g')

			" if there is no mapping of this length which satisfies the previously
			" typed in characters, then proceed to the next length group...
			if !exists(lhsHash)
				let i = i + 1
				continue
			end

			"  ... otherwise insert the corresponding RHS
			" first generate the required number of back-spaces to erase the
			" previously typed in characters.
			exe "let tokLHS = s:LenStr_".numchars
			let bkspc = substitute(tokLHS, '.$', '', '')
			let bkspc = substitute(bkspc, '.', "\<bs>", "g")

			" get the corresponding RHS
			exe "let ret = ".lhsHash
			
			return bkspc.Tex_PutTextWithMovement(ret)

		endwhile

		let k = k + 1
	endwhile
	
	return a:char
endfunction

" }}}
" IMAP_PutTextWithMovement: appends movement commands to a text  {{{
" 		This enables which cursor placement.
function! IMAP_PutTextWithMovement(text, mark)

	let text = a:text
	let phs = s:PlaceHolderStart()
	let phe = s:PlaceHolderEnd()
	let startpat = escape(phs, '\')
	let endpat = escape(phe, '\')

	" If the user does not want to use place-holders, then remove them.
	if exists('g:Imap_UsePlaceHolders') && !g:Imap_UsePlaceHolders
		" a heavy-handed way to just use the first placeholder and remove the
		" rest.  Replace the first template with phe ...
		let text = substitute(text, '\V'.startpat.'\.\{-}'.endpat, endpat, '')
		" ... delete all the others ...
		let text = substitute(text, '\V'.startpat.'\.\{-}'.endpat, '', 'g')
		" ... and replace the first phe with phs.phe .
		let text = substitute(text, '\V'.endpat, startpat.endpat, '')
	endif

	" template = first <+{...}+> in text, where {...} may be empty.
	let template = matchstr(text, '\V' . startpat . '\.\{-}' . endpat)
	" If there are no place holders, just return the text.
	if strlen(template) == 0
		echomsg 'searching for \V' . startpat . '\.\{-}' . endpat . ' in ' . text
		return text
	endif

	" Now, start building the return value.
	" Return to Normal mode:  this works even if 'insertmode' is set:
	let text = text . "\<C-\>\<C-N>"
	" Start at the position given by mark:
	let text = text . ":" . a:mark . "\<CR>"
	" Look for the first place holder:
	let text = text . ":call search('\\V" . startpat . "', 'W')\<CR>"
	" Finally, append commands to Select <+template+> or replace <++> .
	" Enter Visual mode and move to the end. Use a search strategy instead of
	" computing the length of the template because strlen() returns different
	" things depending on the encoding.
	let text = text . "v/\\V" . endpat . "/e\<CR>\<ESC>"
				\ . s:RemoveLastHistoryItem . "\<CR>gv"
	if template == phs . phe
		" template looks like <++> so Change it:
		let text = text . "c"
	else
		" Enter Select mode.
		let text = text . "\<C-G>"
	endif

	return text
endfunction
" Tex_PutTextWithMovement: old version of IMAP_PutTextWithMovement
" Description:
" 	This function is supplied to maintain backward compatibility. 
" 	This function is only for use in latex-suite.
function! Tex_PutTextWithMovement(text)
	
	let phs = s:PlaceHolderStart()
	let phe = s:PlaceHolderEnd()
	let newText = substitute(a:text, '<+', phs, 'g')
	let newText = substitute(newText, '+>', phe, 'g')

	return IMAP_PutTextWithMovement(newText)

endfunction 

" }}}
" IMAP_Jumpfunc: takes user to next <+place-holder+> {{{
" Author: Luc Hermitte
"
function! IMAP_Jumpfunc()

	let phs = escape(s:PlaceHolderStart(), '\')
	let phe = escape(s:PlaceHolderEnd(), '\')

	if !search(phs.'.\{-}' . phe, 'W')  "no more marks
		return ""
	else
		if strpart(getline('.'), col('.') + strlen(phs) - 1)
					\ =~  '^' . phe

			return substitute(phs . phe, '.', "\<Del>", 'g')
		else
			if col('.') > 1
				return "\<Esc>lv/\\V" . phe . "/e\<CR>\<C-g>"
			else
				return "\<C-\>\<C-n>v/\\V" . phe . "/e\<CR>\<C-g>"
			endif
		endif
	endif
endfunction

" map only if there is no mapping already. allows for user customization.
if !hasmapto('IMAP_Jumpfunc')
    inoremap <C-J> <c-r>=IMAP_Jumpfunc()<CR>
    nmap <C-J> i<C-J>
end
" }}}
" RestoreEncoding: restores file encoding to what it was originally {{{
" Description: 
function! RestoreEncoding()
	if s:oldenc != 'latin1'
		let &g:encoding = s:oldenc
	endif
	return ''
endfunction " }}}

nmap <silent> <script> <plug><+SelectRegion+> `<v`>

" ============================================================================== 
" enclosing selected region.
" ============================================================================== 
" VEnclose: encloses the visually selected region with given arguments {{{
" Description: allows for differing action based on visual line wise
"              selection or visual characterwise selection. preserves the
"              marks and search history.
function! VEnclose(vstart, vend, VStart, VEnd)

	" its characterwise if
	" 1. characterwise selection and valid values for vstart and vend.
	" OR
	" 2. linewise selection and invalid values for VStart and VEnd
	if (visualmode() == 'v' && (a:vstart != '' || a:vend != '')) || (a:VStart == '' && a:VEnd == '')

		let newline = ""
		let _r = @r

		let normcmd = "normal! \<C-\>\<C-n>`<v`>\"_s"

		exe "normal! \<C-\>\<C-n>`<v`>\"ry"
		if @r =~ "\n$"
			let newline = "\n"
			let @r = substitute(@r, "\n$", '', '')
		endif

		let normcmd = normcmd.
			\a:vstart."!!mark!!".a:vend.newline.
			\"\<C-\>\<C-N>?!!mark!!\<CR>v7l\"_s\<C-r>r\<C-\>\<C-n>"

		" this little if statement is because till very recently, vim used to
		" report col("'>") > length of selected line when `> is $. on some
		" systems it reports a -ve number.
		if col("'>") < 0 || col("'>") > strlen(getline("'>"))
			let lastcol = strlen(getline("'>"))
		else
			let lastcol = col("'>")
		endif
		if lastcol - col("'<") != 0
			let len = lastcol - col("'<")
		else
			let len = ''
		endif

		" the next normal! is for restoring the marks.
		let normcmd = normcmd."`<v".len."l\<C-\>\<C-N>"

		silent! exe normcmd
		" this is to restore the r register.
		let @r = _r
		" and finally, this is to restore the search history.
		execute s:RemoveLastHistoryItem

	else

		exec 'normal! `<O'.a:VStart."\<C-\>\<C-n>"
		exec 'normal! `>o'.a:VEnd."\<C-\>\<C-n>"
		if &indentexpr != ''
			silent! normal! `<kV`>j=
		endif
		silent! normal! `>
	endif
endfunction 

" }}}
" ExecMap: adds the ability to correct an normal/visual mode mapping.  {{{
" Author: Hari Krishna Dara <hari_vim@yahoo.com>
" Reads a normal mode mapping at the command line and executes it with the
" given prefix. Press <BS> to correct and <Esc> to cancel.
function! ExecMap(prefix, mode)
	" Temporarily remove the mapping, otherwise it will interfere with the
	" mapcheck call below:
	let myMap = maparg(a:prefix, a:mode)
	exec a:mode."unmap ".a:prefix

	" Generate a line with spaces to clear the previous message.
	let i = 1
	let clearLine = "\r"
	while i < &columns
		let clearLine = clearLine . ' '
		let i = i + 1
	endwhile

	let mapCmd = a:prefix
	let foundMap = 0
	let breakLoop = 0
	echon "\rEnter Map: " . mapCmd
	while !breakLoop
		let char = getchar()
		if char !~ '^\d\+$'
			if char == "\<BS>"
				let mapCmd = strpart(mapCmd, 0, strlen(mapCmd) - 1)
			endif
		else " It is the ascii code.
			let char = nr2char(char)
			if char == "\<Esc>"
				let breakLoop = 1
			else
				let mapCmd = mapCmd . char
				if maparg(mapCmd, a:mode) != ""
					let foundMap = 1
					let breakLoop = 1
				elseif mapcheck(mapCmd, a:mode) == ""
					let mapCmd = strpart(mapCmd, 0, strlen(mapCmd) - 1)
				endif
			endif
		endif
		echon clearLine
		echon "\rEnter Map: " . mapCmd
	endwhile
	if foundMap
		if a:mode == 'v'
			" use a plug to select the region instead of using something like
			" `<v`> to avoid problems caused by some of the characters in
			" '`<v`>' being mapped.
			let gotoc = "\<plug><+SelectRegion+>"
		else
			let gotoc = ''
		endif
		exec "normal ".gotoc.mapCmd
	endif
	exec a:mode.'noremap '.a:prefix.' '.myMap
endfunction

" }}}

" ============================================================================== 
" helper functions
" ============================================================================== 
" Strntok: extract the n^th token from a list {{{
" example: Strntok('1,23,3', ',', 2) = 23
fun! <SID>Strntok(s, tok, n)
	return matchstr( a:s.a:tok[0], '\v(\zs([^'.a:tok.']*)\ze['.a:tok.']){'.a:n.'}')
endfun

" }}}
" s:RemoveLastHistoryItem: removes last search item from search history {{{
" Description: Execute this string to clean up the search history.
let s:RemoveLastHistoryItem = ':call histdel("/", -1)|let @/=histget("/", -1)'

" }}}
" Hash: Return a version of a string that can be used as part of a variable" {{{
" name.
fun! s:Hash(text)
	return substitute(a:text, '\([^[:alnum:]]\)',
				\ '\="_".char2nr(submatch(1))."_"', 'g')
endfun
"" }}}
" PlaceHolderStart and PlaceHolderEnd:  return the buffer-local " {{{
" variable, or the global one, or the default.
fun! s:PlaceHolderStart()
	if exists("b:Imap_PlaceHolderStart")
		return b:Imap_PlaceHolderStart
	elseif exists("g:Imap_PlaceHolderStart")
		return g:Imap_PlaceHolderStart
	else
		return "<+"
endfun
fun! s:PlaceHolderEnd()
	if exists("b:Imap_PlaceHolderEnd")
		return b:Imap_PlaceHolderEnd
	elseif exists("g:Imap_PlaceHolderEnd")
		return g:Imap_PlaceHolderEnd
	else
		return "+>"
endfun
" }}}

" ============================================================================== 
" A bonus function: Snip()
" ============================================================================== 
" Snip: puts a scissor string above and below block of text {{{
" Desciption:
"-------------------------------------%<-------------------------------------
"   this puts a the string "--------%<---------" above and below the visually
"   selected block of lines. the length of the 'tearoff' string depends on the
"   maximum string length in the selected range. this is an aesthetically more
"   pleasing alternative instead of hardcoding a length.
"-------------------------------------%<-------------------------------------
function! <SID>Snip() range
	let i = a:firstline
	let maxlen = -2
	" find out the maximum virtual length of each line.
	while i <= a:lastline
		exe i
		let length = virtcol('$')
		let maxlen = (length > maxlen ? length : maxlen)
		let i = i + 1
	endwhile
	let maxlen = (maxlen > &tw && &tw != 0 ? &tw : maxlen)
	let half = maxlen/2
	exe a:lastline
	" put a string below
	exe "norm! o\<esc>".(half - 1)."a-\<esc>A%<\<esc>".(half - 1)."a-"
	" and above. its necessary to put the string below the block of lines
	" first because that way the first line number doesnt change...
	exe a:firstline
	exe "norm! O\<esc>".(half - 1)."a-\<esc>A%<\<esc>".(half - 1)."a-"
endfunction

com! -nargs=0 -range Snip :<line1>,<line2>call <SID>Snip()
" }}}

" vim:ft=vim:ts=4:sw=4:noet:fdm=marker:commentstring=\"\ %s:nowrap
