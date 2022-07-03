title 
 fcb $2,$20+8,$20+1,$1b,$32,3
 fcc "/) Invaders 09  V1.04 (\"
 fcb $2,$20+10,$20+2,$1b,$32,2
 fcc "The Invasion Begins!"
 fcb $2,$20+1,$20+4,$1b,$32,3
 fcc "Copyright (C) 94-2015 by Allen Huffman"
 fcb $2,$20+3,$20+5
 fcc   "with updates/fixes by Robert Gault"
 fcb $2,$20+18,$20+7,$1b,$32,1
 fcc "and"
 fcb $2,$20+11,$20+9,$1b,$32,3
 fcc            "Sub-Etha Software"
 fcb $2,$20+8,$20+10
 fcc         "www.SubEthaSoftware.com"
*fcb $2,$20+6,$20+11
*fcc       "PO Box 22031 Clive IA 50325"
 fcb $2,$20+1,$20+12,$1b,$32,2
*fcc "Support the future of OS-9 & the CoCo."
 fcc "If you enjoy this, feel free to tip me"
 fcb $2,$20+1,$20+13
 fcc "a dollar. PayPal alsplace@pobox.com :)"
*fcc "Please do not pirate this program."
 fcb $2,$20+3,$20+15,$1b,$32,3
 fcc "Special thanks to Robert Gault for"
 fcb $2,$20+2,$20+16
 fcc "endless code contributions, and beta"
 fcb $2,$20+2,$20+17
 fcc "crew Colin, Bob, Alex & Bro. Jeremy."
 fcb $2,$20+4,$20+23
 fcc "(J)oystick   (K)eyboard   (Q)uit"
titlelen equ *-title
