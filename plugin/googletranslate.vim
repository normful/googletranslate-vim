" vim:set ts=8 sts=2 sw=2 tw=0:
"
" googletranslate.vim - Translate between English and Locale Language using Google
" @see [https://cloud.google.com/translate/v2/getting_started]
" @see [https://cloud.google.com/translate/v2/using_rest]
"
" Author:	Yasuhiro Matsumoto <mattn.jp@gmail.com>
" Contribute:	hotoo (闲耘™)
" Contribute:	MURAOKA Taro <koron.kaoriya@gmail.com>
" Based On:     excitetranslate.vim
" Last Change:	29-Nov-2011.
" Dependencies: mattn/webapi-vim

if !exists('g:googletranslate_options')
  let g:googletranslate_options = ["register","buffer"]
endif
" default language setting.
if !exists('g:googletranslate_locale')
  let g:googletranslate_locale = substitute(v:lang, '^\([a-z]*\).*$', '\1', '')
endif

let s:endpoint = 'https://www.googleapis.com/language/translate/v2'

function! s:CheckLang(word)
  let all = strlen(a:word)
  let eng = strlen(substitute(a:word, '[^\t -~]', '', 'g'))
  return eng * 2 < all ? '' : 'en'
endfunction

function! s:nr2byte(nr)
  if a:nr < 0x80
    return nr2char(a:nr)
  elseif a:nr < 0x800
    return nr2char(a:nr/64+192).nr2char(a:nr%64+128)
  else
    return nr2char(a:nr/4096%16+224).nr2char(a:nr/64%64+128).nr2char(a:nr%64+128)
  endif
endfunction

function! s:nr2enc_char(charcode)
  if &encoding == 'utf-8'
    return nr2char(a:charcode)
  endif
  let char = s:nr2byte(a:charcode)
  if strlen(char) > 1
    let char = strtrans(iconv(char, 'utf-8', &encoding))
  endif
  return char
endfunction

" @see http://vim.g.hatena.ne.jp/eclipse-a/20080707/1215395816
function! s:char2hex(c)
  if a:c =~# '^[:cntrl:]$' | return '' | endif
  let r = ''
  for i in range(strlen(a:c))
    let r .= printf('%%%02X', char2nr(a:c[i]))
  endfor
  return r
endfunction

function! s:quote(s)
  let q = '"'
  if &shellxquote == '"'
    let q = "'"
  endif
  return q.a:s.q
endfunction

function! GoogleTranslate(word, from, to)
  if exists("g:googletranslate_apikey") == 0
    redraw
    echohl ErrorMsg
    echomsg "Google Translate changed term to use APIs."
    echomsg "If you want to use this plugin continued,"
    echomsg "Please set your API key to `g:googletranslate_apikey`."
    echohl None
    return ''
  endif
  let opt = {"q": a:word, "source": a:from, "target": a:to, "key": g:googletranslate_apikey}
  let res = webapi#http#get(s:endpoint, opt)
  let obj = webapi#json#decode(res.content)
  if exists("obj.data") && type(obj.data) == 4
    let text = obj.data.translations[0].translatedText
    let text = substitute(text, '&gt;', '>', 'g')
    let text = substitute(text, '&lt;', '<', 'g')
    let text = substitute(text, '&quot;', '"', 'g')
    let text = substitute(text, '&apos;', "'", 'g')
    let text = substitute(text, '&nbsp;', ' ', 'g')
    let text = substitute(text, '&yen;', '\&#65509;', 'g')
    let text = substitute(text, '&#\(\d\+\);', '\=s:nr2enc_char(submatch(1))', 'g')
    let text = substitute(text, '&amp;', '\&', 'g')
  else
    echomsg "Original request:"
    echo opt
    echomsg "Error response:"
    echo obj
    echohl WarningMsg
    echohl None
    let text = ''
  endif
  return text
endfunction

function! GoogleTranslateRange(...) range
  " Concatenate input string.
  let curline = a:firstline
  let strline = ''

  if a:0 >= 3
    let strline = a:3
  else
    while curline <= a:lastline
      let tmpline = substitute(getline(curline), '^\s\+\|\s\+$', '', 'g')
      if tmpline=~ '\m^\a' && strline =~ '\m\a$'
        let strline = strline .' '. tmpline
      else
        let strline = strline . tmpline
      endif
      let curline = curline + 1
    endwhile
  endif

  let from = ''
  let to = g:googletranslate_locale
  if a:0 == 0
    let from = s:CheckLang(strline) == 'en' ? 'en' : g:googletranslate_locale
    let to = 'en'==from ? g:googletranslate_locale : 'en'
  elseif a:0 == 1
    let to = a:1
  elseif a:0 >= 2
    let from = a:1
    let to = a:2
  endif

  " Do translate.
  let jstr = GoogleTranslate(strline, from, to)
  if len(jstr) == 0
    return
  endif

  " Echo
  if index(g:googletranslate_options, 'echo') != -1
    echo jstr
  endif
  " Put to buffer.
  if index(g:googletranslate_options, 'buffer') != -1
    " Open or go result buffer.
    let bufname = '==Google Translate=='
    let winnr = bufwinnr(bufname)
    if winnr < 1
      silent execute 'below 10new '.escape(bufname, ' ')
      nmap <buffer> q :<c-g><c-u>bw!<cr>
      vmap <buffer> q :<c-g><c-u>bw!<cr>
    else
      if winnr != winnr()
	execute winnr.'wincmd w'
      endif
    endif
    setlocal buftype=nofile bufhidden=hide noswapfile wrap ft=
    " Append translated string.
    if line('$') == 1 && getline('$').'X' ==# 'X'
      call setline(1, jstr)
    else
      call append(line('$'), '--------')
      call append(line('$'), jstr)
    endif
    normal! Gzt
  endif
  " Put to unnamed register.
  if index(g:googletranslate_options, 'register') != -1
    let @" = jstr
  endif
endfunction

command! -nargs=* -range GoogleTranslate <line1>,<line2>call GoogleTranslateRange(<f-args>)
command! -nargs=* -range Trans <line1>,<line2>call GoogleTranslateRange(<f-args>)
