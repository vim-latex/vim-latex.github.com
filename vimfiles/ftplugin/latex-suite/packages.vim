"=============================================================================
" 	     File: packages.vim
"      Author: Mikolaj Machowski
"     Created: Tue Apr 23 06:00 PM 2002 PST
" Last Change: Sun Dec 22 02:00 AM 2002 PST
" 
"  Description: handling packages from within vim
"=============================================================================

" avoid reinclusion.
" TODO: This is no longer true. A package does more things than just make
" menus.
" if !g:Tex_PackagesMenu || exists('s:doneOnce')
" 	finish
" endif
" let s:doneOnce = 1

" Level of Packages menu: 
let s:p_menu_lev = g:Tex_PackagesMenuLocation

let s:path = expand("<sfile>:p:h")
let s:menu_div = 20

com! -nargs=* TPackage call Tex_pack_one(<f-args>)
com! -nargs=0 TPackageUpdate :silent! call Tex_pack_updateall()
com! -nargs=0 TPackageUpdateAll :silent! call Tex_pack_updateall()

imap <silent> <plug> <Nop>
nmap <silent> <plug> i

let g:Tex_package_supported = ''
let g:Tex_package_detected = ''

" Tex_pack_check: creates the package menu and adds to 'dict' setting. {{{
"
function! Tex_pack_check(package)
	if filereadable(s:path.'/packages/'.a:package)
		exe 'source ' . s:path . '/packages/' . a:package
		if has("gui_running")
			" TODO: Didn't we hav an option for the menus here...
			call Tex_pack(a:package)
		endif
		let g:Tex_package_supported = g:Tex_package_supported.','.a:package
	endif
	if filereadable(s:path.'/dictionaries/'.a:package)
		exe 'setlocal dict+='.s:path.'/dictionaries/'.a:package
		if !has("gui_running") && filereadable(s:path.'/dictionaries/'.a:package)
			let g:Tex_package_supported = g:Tex_package_supported.','.a:package
			" TODO: This means that the list contains dupes if the package and
			" the dictionary both exist...
		endif
	endif
	let g:Tex_package_supported = substitute(g:Tex_package_supported, '^,', '', '')
endfunction

" }}}
" Tex_pack_uncheck: removes package from menu and 'dict' settings. {{{
function! Tex_pack_uncheck(package)
	if has("gui_running") && filereadable(s:path.'/packages/'.a:package)
		exe 'silent! aunmenu '.s:p_menu_lev.'&'.a:package
	endif
	if filereadable(s:path.'/dictionaries/'.a:package)
		exe 'setlocal dict-='.s:path.'/dictionaries/'.a:package
	endif
endfunction

" }}}
" Tex_pack_updateall: {{{
function! Tex_pack_updateall()
	if exists('g:Tex_package_supported')
		let i = 1
		while 1
			let old_pack_name = Tex_Strntok(g:Tex_package_supported, ',', i)
			if old_pack_name == ''
				break
			endif
			call Tex_pack_uncheck(old_pack_name)
			let i = i + 1
		endwhile
		let g:Tex_package_supported = ''
		let g:Tex_package_detected = ''
		call Tex_pack_all()
	else
		call Tex_pack_all()
	endif
endfunction

" }}}
" Tex_pack_one: {{{
" Reads command-line and adds appropriate \usepackage lines 
function! Tex_pack_one(...)
	if a:0 == 0
		let pwd = getcwd()
		exe 'cd '.s:path.'/packages'
		let packname = Tex_ChooseFile('Choose a package: ')
		exe 'cd '.pwd
		call Tex_pack_check(packname)
		return Tex_pack_supp(packname)
	elseif a:0 == 1
		if filereadable(s:path.'/packages/'.a:1)
			return Tex_pack_supp(a:1)
		endif
	else
		" TODO: What does this while loop do?
		" Are we actually searching for things like
		"   s:path/packages/1
		" etc?!!
		let i = a:0
		let omega = 1
		while omega <= i
			exe 'let packname = a:'.omega
			if filereadable(s:path.'/packages/'.packname)
				call Tex_pack_check(packname)
				exe 'normal ko\usepackage{'.packname."}\<Esc>"
				let omega = omega + 1
			endif
		endwhile
	endif
endfunction
" }}}
" Tex_pack_all: scans the current file for \\usepackage{ lines {{{
"               and loads the corresponding package options as menus.
function! Tex_pack_all()

	let pos = line('.').' | normal! '.virtcol('.').'|'
	let currfile = expand('%:p')

	if Tex_GetMainFileName() != ''
		let cwd = getcwd()
		let fname = Tex_GetMainFileName()
		" TODO: Change Tex_GetMainFileName to return file name with extension.
		"       (maybe in the presence of an optional argument)
		if glob(fname.'.tex') != ''
			let fname = fname.'.tex'
		elseif glob(fname) != ''
			let fname = ''
		else
			let fname = currfile
		endif
	else
		let fname = currfile
	endif

	let toquit = 0
	if fname != currfile
		exe 'split '.fname
		let toquit = 1
	endif

	exe 0
	let beginline = search('\\begin{document}', 'W')
	exe 0
	let oldpack = ''
	let packname = ''
	while search('usepackage.*', 'W')
		if line('.') > beginline 
			break
		elseif getline('.') =~ '^\s*%'
			continue
		elseif getline('.') =~ '^[^%]\{-}\\usepackage[^{]\{-}[%$]'
			let packname = matchstr(getline(search('^[^%]\{-}\]{', 'W')), '^.\{-}\]{\zs[^}]*\ze}')
		elseif getline('.') =~ '^[^%]\{-}\\usepackage'
			let packname = matchstr(getline("."), '^[^%]\{-}usepackage.\{-}{\zs[^}]*\ze}')
		endif
		let packname = substitute(packname, '\s', '', 'g')
		if packname =~ ','
			let i = 1
			while 1
				let pname = Tex_Strntok(packname, ',', i)
				if pname == ''
					break
				endif
				let g:Tex_package_detected = g:Tex_package_detected.' '.pname
				call Tex_pack_check(pname)
				let i = i + 1
			endwhile
		elseif oldpack != packname
			let g:Tex_package_detected = g:Tex_package_detected.' '.packname
			call Tex_pack_check(packname)
		endif
		let oldpack = packname
	endwhile

	if toquit
		q	
	endif
	exe pos
endfunction
   
" }}}
" Tex_pack_supp_menu: sets up a menu for packages found in packages/ {{{
"                     groups the packages thus found into groups of 20...
function! Tex_pack_supp_menu()

	let pwd = getcwd()
	exec 'cd '.s:path.'/packages'
	let suplist = glob("*")
	exec 'cd '.pwd

	let suplist = substitute(suplist, "\n", ',', 'g').','

	call Tex_MakeSubmenu(suplist, g:Tex_PackagesMenuLocation.'Supported.', 
		\ '<plug><C-r>=Tex_pack_supp("', '")<CR>')
endfunction 

" }}}

" Tex_MakeSubmenu: makes a submenu given a list of items {{{
" Description: 
function! Tex_MakeSubmenu(menuList, MainMenuName, HandlerFuncLHS, HandlerFuncRHS, ...)

	let extractPattern = ''
	if a:0 > 0
		let extractPattern = a:1
	endif
	let menuList = a:menuList
	if menuList !~ ',$'
		let menuList = menuList.','
	endif
	let doneMenuSubmenu = 0

	while menuList != ''

		" Extract upto s:menu_div menus at once.
		let menuBunch = matchstr(menuList, '\v(.{-},){,'.s:menu_div.'}')
		" echomsg 'bunch = '.menuBunch

		" The remaining menus go into the list.
		let menuList = strpart(menuList, strlen(menuBunch))

		let submenu = ''
		" If there is something remaining, then we got s:menu_div items.
		" therefore put these menu items into a submenu.
		if strlen(menuList) || doneMenuSubmenu
			let firstMenu = matchstr(menuBunch, '\v^.{-}\ze,')
			let lastMenu = matchstr(menuBunch, '\v[^,]{-}\ze,$')

			let submenu = substitute(firstMenu, extractPattern, '\1', '').
				\ '\ -\ '.substitute(lastMenu, extractPattern, '\1', '').'.'

			let doneMenuSubmenu = 1
		endif

		" Now for each menu create a menu under the submenu
		let i = 1
		let menuName = Tex_Strntok(menuBunch, ',', i)
		while menuName != ''
			let menuItem = substitute(menuName, extractPattern, '\1', '')
			execute 'amenu '.a:MainMenuName.submenu.menuItem
				\ '       '.a:HandlerFuncLHS.menuName.a:HandlerFuncRHS

			let i = i + 1
			let menuName = Tex_Strntok(menuBunch, ',', i)
		endwhile
	endwhile
endfunction 

" }}}
" Tex_pack: loads the options (and commands) for the given package {{{
function! Tex_pack(pack)
	let basic_nu_p_list = ''
	let nu_p_list = '' 

	if exists('g:TeX_package_'.a:pack)

		let g:p_list = g:TeX_package_{a:pack}
		let g:p_o_list = g:TeX_package_option_{a:pack}

		let optionList = g:TeX_package_option_{a:pack}.','
		let doneOptionSubmenu = 0

		if optionList != ''

			let mainMenuName = g:Tex_PackagesMenuLocation.a:pack.'.Options.'
			call Tex_MakeSubmenu(optionList, mainMenuName, 
				\ '<plug><C-r>=IMAP_PutTextWithMovement("', ',")<CR>')

		endif

		let commandList = g:TeX_package_{a:pack}

		while matchstr(commandList, 'sbr:') != ''

			call Tex_Debug('command list = '.commandList)

			let groupName = matchstr(commandList, '\v^sbr:\zs.{-}\ze,')
			let commandList = strpart(commandList, strlen('sbr:'.groupName) + 1)
			if matchstr(commandList, 'sbr:') != ''
				let commandGroup = matchstr(commandList, '\v^.{-},\zesbr:')
			else
				let commandGroup = commandList
			endif

			let menuName = g:Tex_PackagesMenuLocation.a:pack.'.Commands.'
			let menuName = menuName.groupName.'.'
			call Tex_MakeSubmenu(commandGroup, menuName, "<plug><C-r>=Tex_ProcessPackageCommand('", "')<CR>", '\w\+:\(\w\+\).*')

			let commandList = strpart(commandList, strlen(commandGroup))
		endwhile

		call Tex_MakeSubmenu(commandList, g:Tex_PackagesMenuLocation.a:pack.'.Commands.',
			\ '<plug><C-r>=IMAP_PutTextWithMovement("', ',")<CR>', '\w\+:\(\w\+\).*')

	endif
endfunction 

" }}}
" Definition of what to do for various package commands {{{
let s:CommandSpec_bra = '\<+replace+>{<++>}<++>'
let s:CommandSpec_brs = '\<+replace+><++>'
let s:CommandSpec_brd = '\<+replace+>{<++>}{<++>}<++>'
let s:CommandSpec_env = '\begin{<+replace+>}'."\<CR><++>\<CR>".'\end{<+replace+>}<++>'
let s:CommandSpec_ens = '\begin{<+replace+>}'."\<CR><++>\<CR>".'\end{<+replace+>}<++>'
let s:CommandSpec_eno = '\begin[<++>]{<+replace+>}'."\<CR><++>\<CR>".'\end{<+replace+>}'
let s:CommandSpec_nor = '\<+replace+>'
let s:CommandSpec_noo = '\<+replace+>[<++>]'
let s:CommandSpec_nob = '\<+replace+>[<++>]{<++>}{<++>}<++>'
let s:CommandSpec_spe = '<+replace+>'
let s:CommandSpec_    = '\<+replace+>'

" }}}
" Tex_ProcessPackageCommand: processes a command from the package menu {{{
" Description: 
function! Tex_ProcessPackageCommand(command)
	let commandType = matchstr(a:command, '^\w\+\ze:')
	let commandName = strpart(a:command, strlen(commandType.':'))

	return IMAP_PutTextWithMovement(
		\ substitute(s:CommandSpec_{commandType}, '<+replace+>', commandName, 'g'))
endfunction 
" }}}
" Tex_pack_supp: "supports" the package... {{{
function! Tex_pack_supp(supp_pack)
	call Tex_pack_check(a:supp_pack)
	exe 'let g:s_p_o = g:TeX_package_option_'.a:supp_pack 
	if exists('g:s_p_o') && g:s_p_o != ''
		return IMAP_PutTextWithMovement('\usepackage[<++>]{'.a:supp_pack.'}<++>', '<+', '+>')
	else
		return IMAP_PutTextWithMovement('\usepackage{'.a:supp_pack.'}<++>', '<+', '+>')
	endif
	if g:Tex_package_supported == ''
		let g:Tex_package_supported = a:supp_pack
	else
		let g:Tex_package_supported = g:Tex_package_supported.','.a:supp_pack
	endif
endfunction

" }}}
" Tex_PutPackage: inserts package from line {{{
" (see Tex_package_from_line in envmacros.vim)
function! Tex_PutPackage(package)
	if filereadable(s:path.'/packages/'.a:package)
		return Tex_pack_supp(a:package)
	else
		return IMAP_PutTextWithMovement('\usepackage{'.a:package.'}')
	endif
	call Tex_pack_updateall()
endfunction	" }}}

if g:Tex_Menus

	exe 'amenu '.s:p_menu_lev.'&UpdatePackage :call Tex_pack(expand("<cword>"))<cr>'
	exe 'amenu '.s:p_menu_lev.'&UpdateAll :call Tex_pack_updateall()<cr>'

 	call Tex_pack_supp_menu()
 	call Tex_pack_all()

endif

" vim:fdm=marker:ts=4:sw=4:noet:fo-=wa1
