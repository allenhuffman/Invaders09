helpmsg fcb $d,$a
 fcc "Invaders 1.04 by Allen Huffman (alsplace@pobox.com)"
 fcb $d,$a
 fcc "with updates/fixes by Robert Gault."
 fcb $d,$a
 fcc "Copyright (C) 1994,95,2015 by Sub-Etha Software. www.subethasoftware.com"
 fcb $d,$a,$d,$a
 fcc "Syntax: Invaders [-opts]"
 fcb $d,$a
 fcc "Usage : LEFT/RIGHT to Move, SPACE to Fire, P to Pause, Q to Quit."
 fcb $d,$a
 fcc "Opts  : -? = display this message."
 fcb $d,$a
 fcc "        -m = monochrome colors (for 'montype m' displays)."
 fcb $d,$a
 fcc "        -z = secret option if you think it is too slow."
 fcb $d,$a
 fcc "        -* = secret cheat mode (press * to skip level)."
 fcb $d,$a
helpsize equ *-helpmsg
