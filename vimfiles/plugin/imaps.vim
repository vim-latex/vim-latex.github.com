"        File: imaps.vim
"     Authors: Srinath Avadhanula <srinath AT fastmail.fm>
"              Benji Fisher <benji AT member.AMS.org>
"              
"         WWW: http://cvs.sourceforge.net/cgi-bin/viewcvs.cgi/vim-latex/vimfiles/plugin/imaps.vim?only_with_tag=MAIN
"
" Description: insert mode template expander with cursor placement
"              while preserving filetype indentation.
"
" Last Change: Thu Dec 19 03:00 AM 2002 PST
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
" call IMAP (lhs, rhs, ft)
" 
" Some characters in the RHS have special meaning which help in cursor
" placement.
"
" Example One:
"
" 	call IMAP ("bit`", "\\begin{itemize}\<cr>\\item <++>\<cr>\\end{itemize}<++>", "tex")
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
"	call IMAP ('date`', "\<c-r>=strftime('%b %d %Y')\<cr>", '')
"
" sets up the map for date` to insert the current date.
"
"--------------------------------------%<--------------------------------------
" Bonus: This script also provides a command Snip which puts tearoff strings,
" '----%<----' above and below the visually selected range of lines. The
" length of the string is chosen to be equal to the longest line in the range.
" Recommended Usage:
"   '<,'>Snip
"--------------------------------------%<--------------------------------------
" }}}

" ==============================================================================
" Script variables
" ==============================================================================
" {{{
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
"           IMAP('abc', 'def' ft) 
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

" IMAP: set up a filetype specific mapping.
" Description:
"   "maps" the lhs to rhs in files of type 'ft'. If supplied with 2
"   additional arguments, then those are assumed to be the placeholder
"   characters in rhs. If unspecified, then the placeholder characters
"   are assumed to be '<+' and '+>' These placeholder characters in
"   a:rhs are replaced with the users setting of
"   [bg]:Imap_PlaceHolderStart and [bg]:Imap_PlaceHolderEnd settings.
"
function! IMAP(lhs, rhs, ft, ...)

	" Find the place holders to save for IMAP_PutTextWithMovement() .
	if a:0 < 2
		let phs = '<+'
		let phe = '+>'
	else
		let phs = a:1
		let phe = a:2
	endif

	let hash = s:Hash(a:lhs)
	let s:Map_{a:ft}_{hash} = a:rhs
	let s:phs_{a:ft}_{hash} = phs
	let s:phe_{a:ft}_{hash} = phe

	" Add a:lhs to the list of left-hand sides that end with lastLHSChar:
	let lastLHSChar = a:lhs[strlen(a:lhs)-1]
	let hash = s:Hash(lastLHSChar)
	if !exists("s:LHS_" . a:ft . "_" . hash)
		let s:LHS_{a:ft}_{hash} = escape(a:lhs, '\')
	else
		let s:LHS_{a:ft}_{hash} = escape(a:lhs, '\') .'\|'.  s:LHS_{a:ft}_{hash}
	endif

	" map only the last character of the left-hand side.
	if lastLHSChar == ' '
		let lastLHSChar = '<space>'
	end
	exe 'inoremap <silent>' (a:ft== '' ? '' : '<buffer>')
				\ escape(lastLHSChar, '|')
				\ '<C-r>=<SID>LookupCharacter("' .
				\ escape(lastLHSChar, '\|') .
				\ '")<CR>'
endfunction

" }}}
" LookupCharacter: inserts mapping corresponding to this character {{{
"
" This function extracts from s:LHS_{&ft}_{a:char} or s:LHS__{a:char}
" the longest lhs matching the current text.  Then it replaces lhs with the
" corresponding rhs saved in s:Map_{ft}_{lhs} .
" The place-holder variables are passed to IMAP_PutTextWithMovement() .
function! s:LookupCharacter(char)
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
	" matchstr() returns the match that starts first. This automatically
	" ensures that the longest LHS is used for the mapping.
	let lhs = matchstr(text, '\V\(' . s:LHS_{ft}_{charHash} . '\)\$')
	if strlen(lhs) == 0
		return a:char
	endif
	" enough back-spaces to erase the left-hand side; -1 for the last
	" character typed:
	let bs = substitute(strpart(lhs, 1), ".", "\<bs>", "g")
	let hash = s:Hash(lhs)
	return bs . IMAP_PutTextWithMovement(s:Map_{ft}_{hash},
				\ s:phs_{ft}_{hash}, s:phe_{ft}_{hash})
endfunction

" }}}
" IMAP_PutTextWithMovement: returns the string with movement appended {{{
" Description:
"   If a:str contains "placeholders", then appends movement commands to
"   str in a way that the user moves to the first placeholder and enters
"   insert or select mode. If supplied with 2 additional arguments, then
"   they are assumed to be the placeholder specs. Otherwise, they are
"   assumed to be '<+' and '+>'. These placeholder chars are replaced
"   with the users settings of [bg]:Imap_PlaceHolderStart and
"   [bg]:Imap_PlaceHolderEnd.
function! IMAP_PutTextWithMovement(str, ...)

	" The placeholders used in the particular input string. These can be
	" different from what the user wants to use.
	if a:0 < 2
		let phs = '<+'
		let phe = '+>'
	else
		let phs = escape(a:1, '\')
		let phe = escape(a:2, '\')
	endif

	let text = a:str

	" If there are no place holders, just return the text.
	if text !~ '\V'.phs.'\{-}'.phe
		return text
	endif

	" The user's placeholder settings.
	let phsUser = s:PlaceHolderStart()
	let pheUser = s:PlaceHolderEnd()

	" A very rare string: Do not use any special characters here. This is used
	" for moving to the beginning of the inserted text
	let marker = '<!--- @#% Start Here @#% ----!>'
	let markerLength = strlen(marker)

	" If the user does not want to use place-holders, then remove all but the
	" first placeholder
	if exists('g:Imap_UsePlaceHolders') && !g:Imap_UsePlaceHolders
		" a heavy-handed way to just use the first placeholder and remove the
		" rest.  Replace the first placeholder with phe ...
		let text = substitute(text, '\V'.phs.'\.\{-}'.phe, phe, '')
		" ... delete all the others ...
		let text = substitute(text, '\V'.phs.'\.\{-}'.phe, '', 'g')
		" ... and replace the first phe with phsUser.pheUser .
		let text = substitute(text, '\V'.phe, phsUser.pheUser, '')
	endif

	" now replace all occurences of the placeholders here with the users choice
	" of placeholder settings.
	" NOTE: There can be more than 1 placeholders here. Therefore use a global
	"       search and replace.
	let text = substitute(text, '\V'.phs.'\(\.\{-}\)'.phe, phsUser.'\1'.pheUser, 'g')
	" Now append the marker (the rare string) to the beginning of the text so
	" we know where the expansion started from
	let text = marker.text

	" This search will move us to the very beginning of the text to be
	" inserted.
	" The steps are:
	" 1. enter escape mode (using <C-\><C-n> so it works in insertmode as
	"    well)
	" 2. Search backward for marker text.
	" 3. delete from the beginning to the end of marker into the blackhole
	"    register.
	let movement = "\<C-\>\<C-N>"
				\ . "?\\V".marker."\<CR>"
				\ . '"_d/\V'.marker."/e\<CR>"

	" Now enter insert mode and call IMAP_Jumpfunc() to take us to the next
	" placeholder and get us either into visual or insert mode. Since we do
	" at least one search in this function, remove it from the search history
	" first.
	" NOTE: Even if we performed more than one search, vim will only put one
	"       of them in the user's search list.
	let movement = movement.':'.s:RemoveLastHistoryItem."\<CR>"
			\ . "i\<C-r>=IMAP_Jumpfunc('', 1)\<CR>"

	return text.movement
endfunction

" }}}
" IMAP_Jumpfunc: takes user to next <+place-holder+> {{{
" Author: Luc Hermitte
"
function! IMAP_Jumpfunc(direction, inclusive)

	let g:Imap_DeleteEmptyPlaceHolders = 0

	" The user's placeholder settings.
	let phsUser = s:PlaceHolderStart()
	let pheUser = s:PlaceHolderEnd()

	let searchOpts = a:direction
	" If the user has nowrapscan set, then do not make the search wrap around
	" the end (or beginning) of the file.
	if ! &wrapscan 
		let searchOpts = direction.'W'
	endif

	let searchString = ''
	" If this is not an inclusive search or if it is inclusive, but the
	" current cursor position does not contain a placeholder character, then
	" search for the placeholder characters.
	if !a:inclusive || strpart(getline('.'), col('.')-1) !~ '\V^'.phsUser
		let searchString = '\V'.phsUser.'\.\{-}'.pheUser
	endif

	" If we didn't find any placeholders return quietly.
	if searchString != '' && !search(searchString, searchOpts)
		return ''
	endif

	" At this point, we are at the beginning of a placeholder. 
	" Remember the position here.
	let position = line('.') . "normal! ".virtcol('.').'|'
	" Open any closed folds and make this part of the text visible.
	silent! foldopen!

	" Calculate if we have an empty placeholder or if it contains some
	" description.
	let template = 
		\ matchstr(strpart(getline('.'), col('.')-1),
		\          '\V\^'.phsUser.'\zs\.\{-}\ze'.pheUser)
	let placeHolderEmpty = !strlen(template)

	" This movement command selects the placeholder text. In the forward mode,
	" we select left-right, otherwise right-left.
	if a:direction =~ 'b'
		" If we are going in the backward direction, make the selection from
		" right to left so that a backward search for phsUser doesnt get us
		" back to the same placeholder.
		let movement = "\<C-\>\<C-N>:".position."\<CR>"
			\ . "/\\V".pheUser."/e\<CR>"
			\ . "v?\\V".phsUser."?b\<CR>"
	else
		let movement = "\<C-\>\<C-N>:".position."\<CR>v/\\V".pheUser."/e\<CR>"
	endif

	if placeHolderEmpty && g:Imap_DeleteEmptyPlaceHolders
		" delete the empty placeholder into the blackhole.
		return movement."\"_c\<C-o>:".s:RemoveLastHistoryItem."\<CR>"

	else
		return movement."\<C-\>\<C-N>:".s:RemoveLastHistoryItem."\<CR>gv\<C-g>"

	endif
	
endfunction

" }}}
" Maps for IMAP_Jumpfunc {{{
" map only if there is no mapping already. allows for user customization.
if !hasmapto('IMAP_Jumpfunc')
    inoremap <C-J> <c-r>=IMAP_Jumpfunc('', 0)<CR>
    inoremap <C-K> <c-r>=IMAP_Jumpfunc('b', 0)<CR>
    nmap <C-J> i<C-J>
    nmap <C-K> i<C-K>
	if exists('g:Imap_StickyPlaceHolders') && g:Imap_StickyPlaceHolders
		vmap <C-J> <C-\><C-N>i<C-J>
		vmap <C-K> <C-\><C-N>i<C-K>
	else
		vmap <C-J> <Del>i<C-J>
		vmap <C-K> <Del>i<C-K>
	endif
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
	if exists("b:Imap_PlaceHolderStart") && strlen(b:Imap_PlaceHolderEnd)
		return b:Imap_PlaceHolderStart
	elseif exists("g:Imap_PlaceHolderStart") && strlen(g:Imap_PlaceHolderEnd)
		return g:Imap_PlaceHolderStart
	else
		return "<+"
endfun
fun! s:PlaceHolderEnd()
	if exists("b:Imap_PlaceHolderEnd") && strlen(b:Imap_PlaceHolderEnd)
		return b:Imap_PlaceHolderEnd
	elseif exists("g:Imap_PlaceHolderEnd") && strlen(g:Imap_PlaceHolderEnd)
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
