" ============================================================================
" 	     File: latexm.vim
"      Author: Srinath Avadhanula
"     Created: Sat Jul 05 03:00 PM 2003 
" Description: compile a .tex file multiple times to get cross references
"              right.
"     License: Vim Charityware License
"              Part of vim-latexSuite: http://vim-latex.sourceforge.net
"         CVS: $Id$
" ============================================================================

python <<EOF
import vim
import re, os, string

# isPresentInFile: check if regexp is present in the file {{{
def isPresentInFile(regexp, filename):
	try:
		fp = open(filename)
		fcontents = string.join(fp.readlines(), '')
		fp.close()
		if re.search(regexp, fcontents):
			return 1
		else:
			return None
	except:
		return None

# }}}
# catFile: return the contents of a file. {{{
def catFile(fileName):
	try:
		file = open(fileName)
		lines = string.join(file.readlines(), '')
		file.close()
	except:
		lines = ''
	return lines

# }}}
# compileLatex: compile the main file multiple times as needed. {{{
def compileLatex():
	mainFileName_full = vim.eval("Tex_GetMainFileName(':p:r')")
	mainFileName_root = vim.eval("Tex_GetMainFileName(':p:r:r')")

	if not mainFileName_root:
		mainFileName_full = vim.eval('expand("%:p")')
		mainFileName_root = vim.eval('expand("%:p:r")')
	
	# first run latex once.
	vim.command('silent! call RunLaTeX()')

	if isPresentInFile(r'\\bibdata', mainFileName_root + '.aux'):
		bibFileName = mainFileName_root + '.bbl'

		biblinesBefore = catFile(bibFileName)

		vim.command('echomsg "running bibtex..."')
		vim.command('let temp_mp = &mp | let &mp=\'bibtex\'')
		vim.command('silent! make %s' % mainFileName_root)
		vim.command('let &mp = temp_mp')

		try:
			biblinesAfter = catFile(bibFileName)

			# if the .bbl file changed with this bibtex command, then we need
			# to rerun latex to refresh the bibliography
			if biblinesAfter != biblinesBefore:
				vim.command("echomsg 'running latex a second time because bibliography file changed...'")
			vim.command('silent! call RunLaTeX()')
		except IOError:
			vim.command('echomsg "unable to read [%s], quitting to next stage..."' % bibFileName)

	# check if latex asks us to rerun
	if isPresentInFile('Rerun to get cross-references right', mainFileName_root + '.log'):
		vim.command('echomsg "running latex a third time to get cross-references right..."')
		vim.command('silent! call RunLaTeX()')

# }}}
EOF

" generate a map for compiling multiple times.
nnoremap <buffer> <Plug>Tex_CompileMultipleTimes  :call Tex_CompileMultipleTimes()<CR>

if !hasmapto('<Plug>Tex_CompileMultipleTimes')
	nmap <leader>lm <Plug>Tex_CompileMultipleTimes
endif

" TODO: these will need to go into texrc finally.
" use python if available.
let g:Tex_UsePython = 1
" the system command which pulls in a file.
if &shell =~ 'sh'
	let g:Tex_CatCmd = 'cat'
else
	let g:Tex_CatCmd = 'type'
endif

" Tex_CompileMultipleTimes: compile a latex file multiple times {{{
" Description: compile a latex file multiple times to get cross-references asd
"              right.
function! Tex_CompileMultipleTimes()
	if has('python') && g:Tex_UsePython
		python compileLatex()
	else
		call Tex_CompileMultipleTimes_Vim()
	endif
endfunction " }}}

" Tex_GotoTempFile: open a temp file. reuse from next time on {{{
" Description: 
function! Tex_GotoTempFile()
	if !exists('s:tempFileName')
		let s:tempFileName = tempname()
	endif
	exec 'silent! split '.s:tempFileName
endfunction " }}}
" Tex_IsPresentInFile: finds if a string str, is present in filename {{{
" Description: 
function! Tex_IsPresentInFile(regexp, filename)
	call Tex_GotoTempFile()

	silent! 1,$ d _
	let _report = &report
	let _sc = &sc
	set report=9999999 nosc
	exec 'silent! 0r! '.g:Tex_CatCmd.' '.a:filename
	set nomod
	let &report = _report
	let &sc = _sc

	if search(a:regexp, 'w')
		let retVal = 1
	else
		let retVal = 0
	endif

	silent! bd

	return retVal
endfunction " }}}
" Tex_CatFile: returns the contents of the file in a string {{{
" Description: 
function! Tex_CatFile(filename)
	call Tex_GotoTempFile()

	silent! 1,$ d _

	let _report = &report
	let _sc = &sc
	set report=9999999 nosc
	exec 'silent! 0r! '.g:Tex_CatCmd.' '.a:filename


	set nomod
	let _a = @a
	silent! normal! ggVG"ay
	let retVal = @a
	let @a = _a

	silent! bd
	let &report = _report
	let &sc = _sc
	return retVal
endfunction " }}}
" Tex_CompileMultipleTimes_Vim: vim implementaion of compileLatex() {{{
" Description: compiles a file multiple times to get cross-references right.
function! Tex_CompileMultipleTimes_Vim()
	let mainFileName_root = Tex_GetMainFileName(':p:r:r')

	if mainFileName_root == ''
		let mainFileName_root = expand("%:p:r")
	endif
	
	" first run latex once.
	silent! call RunLaTeX()

	if Tex_IsPresentInFile('\\bibdata', mainFileName_root.'.aux')
		let bibFileName = mainFileName_root . '.bbl'

		let biblinesBefore = Tex_CatFile(bibFileName)

		echomsg "running bibtex..."
		let temp_mp = &mp | let &mp='bibtex'
		exec 'silent! make '.mainFileName_root
		let &mp = temp_mp

		let biblinesAfter = Tex_CatFile(bibFileName)

		if biblinesAfter != biblinesBefore
			echomsg 'running latex a second time because bibliography file changed...'
			silent! call RunLaTeX()
		endif

	endif

	" check if latex asks us to rerun
	if Tex_IsPresentInFile('Rerun to get cross-references right', mainFileName_root.'.log')
		echomsg "running latex a third time to get cross-references right..."
		silent! call RunLaTeX()
	endif
endfunction " }}}

" vim:fdm=marker:nowrap:noet:ff=unix:ts=4:sw=4
