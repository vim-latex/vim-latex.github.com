python <<EOF
import vim
import re

def isPresentInFile(regexp, filename):
	fp = open(filename)
	try:
		fcontents = ''.join(fp.readlines())
		if re.search(regexp, fcontents):
			return 1
		else:
			return None
	except:
		return None

def compileLatex():
	mainFileName_full = vim.eval("Tex_GetMainFileName(':p:r')")
	mainFileName_root = vim.eval("Tex_GetMainFileName(':p:r:r')")

	if not mainFileName_root:
		mainFileName_full = vim.eval('expand("%:p")')
		mainFileName_root = vim.eval('expand("%:p:r")')
	
	# first run latex once.
	vim.command('silent! call RunLaTeX()')

	auxFileName = mainFileName_root + '.aux'
	
	# now check if there are any .bib files used.
	auxFile = open(auxFileName, 'r')
	auxData = ''.join(auxFile.readlines())
	auxFile.close()

	if isPresentInFile(r'\\bibdata', mainFileName_root + '.aux'):
		bibFileName = mainFileName_root + '.bbl'

		try:
			bibFile = open(bibFileName)
			biblinesBefore = ''.join(bibFile.readlines())
			bibFile.close()
		except:
			biblinesBefore = ''

		try:
			vim.command('echomsg "running bibtex..."')
			vim.command('silent! !bibtex %s' % mainFileName_root)

			bibFile = open(bibFileName)
			biblinesAfter = ''.join(bibFile.readlines())
			bibFile.close()

			# if the .bbl file changed with this bibtex command, then we need
			# to rerun latex to refresh the bibliography
			if biblinesAfter != biblinesBefore:
				vim.command("echomsg 'running latex a second time because bibliography file changed...'")
			vim.command('silent! call RunLaTeX()')
		except:
			vim.command('echomsg "unable to read %s, quitting to next stage..."' % bibFileName)

	# check if latex asks us to rerun
	if isPresentInFile('Rerun to get cross-references right', mainFileName_root + '.log'):
		vim.command('echomsg "running latex a third time to get cross-references right..."')
		vim.command('silent! call RunLaTeX()')
EOF

" vim:fdm=marker:nowrap:noet:ff=unix:ts=4:sw=4
