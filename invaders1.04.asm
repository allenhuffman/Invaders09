* do we need to compile everything?  0=Yes, 1=No

QUICK set 0

*
* Invaders.asm V1.04 by Allen C. Huffman
* with many contributions from Robert Gault
* Copyright (C) 1994,95,2015 by Sub-Etha Software
*
* 0.00 08/21/94 - Initial rewrite of segame code.
* 0.01 08/25/94 - NitrOS-9 specific code removed (code by Robert Gault)
* 0.02 08/26/94 - Revisions/RMA bug fixes by Robert Gault
* 0.03 08/27/94 - Data shuffling, ">" for anything outside first 128 bytes
* 0.04 08/30/94 - Hit player, Score, Lives, Composite/NitrOS9 support, ...
* 0.05 08/31/94 - Font installed, Zoom mode
* 0.06 09/02/94 - '-n' fixed, other mods, Level/Rounds added
* 0.07 09/03/94 - Shot control, round boundries, NitrOS9 auto sense (no -n)
* 0.08 09/06/94 - Pause, UFO speed, joystick, fire speed adjust
* 0.09 09/07/94 - Uh...  The version I sent to Australia
* 1.00 09/24/94 - Release version for 1994 Atlanta CoCoFest!
* 1.01 10/26/94 - Robert Gault patch for >512K systems
*                 Since NitrOS9 call does not work for >512K, call removed
* 1.02 01/29/95 - Converting to 16-color gfx screen (whew!)
* 1.03 02/04/95 - Added test for valid screen BEFORE mapping it into MEM R.G.
*                 Moved hiscore and packet (=enemies) to dp. A.H.
* 1.04 02/07/15 - Updated title screen (website, new message).
*                 Added "secret" options to help screen.
*                 Fixed bug that made font not always load.
*                 Fixed shield and border graphics, palette cleanup.
*

TypeLang equ $11    module type / data type
AttRev   equ $81    module attributes / revision
Edition  equ $00    module edition
Stack    equ $200   stack size

MISSILES equ 10     xx missiles
ENEMIES equ 50      xx bad guys
BOMBS equ 4         xx bombs.  WARNING! must not make DP data go past 128!!!!

W equ 1*160*20       initial enemy location offsets
X equ 2*160*20
Y equ 3*160*20
Z equ 4*160*20
EDELAY equ 53       enemy movement delay (speed)
ADELAY equ 5        enemy animation delay
EFRAMES equ 4       4 frames of animation
UFODELAY equ 5      ufo delay
COUNTER equ 1       ENEMIES/EDELAY+1
*BORDER equ %01101001
LBORDER equ $32
RBORDER equ $23
BOTROW equ 181      bottom row of playfield
BDELAY equ 21       enemy bomb delay value
BULLETS equ 3       start out with 3 bullets we can fire
FIRESPEED equ 10

 psect Invaders,TypeLang,AttRev,Edition,Stack,start

 vsect dp           variable storage

* Note: DP access only works with first 128 bytes due to a bug in the RMA
*       compiler!  anything beyond that must not be "lda <label".  Use
*       lda >label or leax >label,u instead.

* Due to an RMA bug, anything that resides in direct page (0-255 bytes) that
* needs to be indexed to must be within the first 128 bytes... So:

enemies rmb ENEMIES*2     100 bytes
missiles rmb MISSILES*2    20 bytes
bombs rmb BOMBS*2           8 bytes = 128 bytes.  Should be okay!

toppart rmb 2       anything above here must be the UFO
ufodir rmb 1
ufowhen rmb 1
ufodelay rmb 1
ufocount rmb 1
ufoleft rmb 2
uforight rmb 2
ufobomb rmb 1
ufobloc rmb 2
ufoloc rmb 2        15 bytes

locx rmb 2          location of player
maxleft rmb 2
maxright rmb 2
firecount rmb 1
kills rmb 1         8 bytes

pointer rmb 2
badguy rmb 10       points to current bad guy data
edir rmb 1          direction
counter rmb 1
edelay rmb 1
ecount rmb 1
acount rmb 1
aframe rmb 1        18 bytes
bdelay rmb 1
bcount rmb 1
elevel rmb 2        enemy start position on screen (how many rows down)
round rmb 1         which round are we on?  (level)
bullets rmb 1       max bullets you can fire
gofast rmb 1

highscore rmb 2     high score
dscore rmb 3        score esc sequence
score rmb  5        actual score bytes
dlives rmb 9        lives esc sequence
lives rmb 2         player's lives bytes
dlevel rmb 9        ditto for level (round)
level rmb 1         level byte
dshots rmb 9        ditto for shots
shots rmb 1         shot byte

oldpath rmb 1       this will get us back to the original screen
path rmb 1          window path
screen rmb 2
end rmb 2
block rmb 2
number rmb 1
offset rmb 2

buffer rmb 2        misc. buffer stuff (1.04 was 2)
pid   rmb 2         place to store process ID and other byte

montype rmb 1       Monitor Type (0=System, else Monochrome)
zoomode rmb 1       0=Normal Speed
ctrltype rmb 1      keyboard=0, joystick=1
cheatmode rmb 1     0=No Cheating!!!

 endsect

StdIn equ 0
StdOut equ 1
StdErr equ 2

* Start.  Scan command line for options, if any...

sigtrap rti         ignore any interrupts

start
 pshs x
 leax sigtrap,pcr   install signal trap (for break/keyboard interrupts)
 os9 F$Icpt
 puls x

 clr <montype       init montype (0=RGB)
 clr <zoomode       init zoom mode (0=Normal Speed)
 clr <ctrltype      init controller type (0=keyboard)
 clr <cheatmode     init cheatmode (0=NO CHEATING!)

scanline
 lda ,x+            get character on command line
 cmpa #32           is it a space?
 beq scanline       if yes, ignore it and keep scanning
 cmpa #$d           is it enter?
 beq continue       if yes, so continue (end of command line)
 cmpa #'-           is it a dash?
 beq option         if yes, so check for option
 bra scanline       go back to start and check for more...

* Found a '-', so see what option follows...

option
 lda ,x+            get next character
 cmpa #32           is it a space?
 beq scanline       yes, go back to scanline
 cmpa #$d           is it enter?
 beq continue       yes, continue
 cmpa #'?           is it a question mark?
 beq usage          if yes, display usage message
 cmpa #'m           is it -m = monochrome
 bne optskip        no, skip
 sta <montype       store monitor type (0=rgb)
 bra option
optskip
 cmpa #'z           is it -z = Zoom Mode?
 bne optskip2       no, skip
 sta <zoomode
 bra option
optskip2
 cmpa #'*           is it -* = Cheat Mode?
 bne optskip3
 sta <cheatmode
 bra option
optskip3
*                   unknown option, print usage

usage
 lda #StdErr        standard error output
 leax helpmsg,pcr   point to help message
 ldy #helpsize      get size
 os9 I$Write        write it

exit clrb           clear b (no error)
error os9 F$Exit    return to OS-9

continue
 clra
 os9 I$Dup
 sta <oldpath
 lda #3             read/write access
 leax window,pcr    location of "/W" string
 os9 I$Open         open path to new window
 bcs error          exit if error
 sta <path          save window path

 leax makewin,pcr   point to makewindow string
 ldy #mwinlen       get length of string
 os9 I$Write        write it

 clrb               ss.opt getstat
 leax enemies,u     point to tmode storage area
 os9 I$GetStt       get current settings
 lbcs error
 clr 4,x            turn off echo
 os9 I$SetStt       update...

 ldb <montype       check monitor type
 cmpb #'m
 bne continue2      if not m, rgb so okay...
 lda <path
 leax setmono,pcr
 ldy #monolen
 os9 I$Write

continue2
 ldx #30            sleep to make sure window gets displayed
 os9 F$Sleep

 lda #StdIn         standard input
 os9 I$Close        close it
 lda #StdOut        and standard output as well
 os9 I$Close
 lda <path
 os9 I$Dup
 lda <path          get path to window
 os9 I$Dup          duplicate it, making it the new standard input

********************* NitrOS9 call deactivated; Sorry A.D *************
* IFEQ 1
nitrostart
 lda <path          NitrOS-9 screen map routine
 ldb #$8f           SS.ScInf
 pshs u             save u (modified by system call)
 os9 I$GetStt       get info on screen
 puls u             restore u
 bcs stockstart     if error, NitrOS9 must not be in use
 stx <offset        save offset of window start in first block
 sta <number        store number of blocks in use
 stb <block+1       store starting block number
 bra mapin
* ENDC

stockstart
******************* test for valid screen; prevent offscreen crash ******
idle lda <path
 ldb #$89           SS.Mouse; this call is supposed to be good for
*                   CC3IO, GrfInt, and WindInt; see manual              *
 leax enemies,u
 ldy #0             automatic port selection
 os9 I$GetStt
 tst ,x             is Pt.Valid good? 0=no 1=yes
 bne OKscr
 ldx #3
 os9 F$Sleep
 bra idle           check again for desired screen as active screen
OKscr ldx #3
 os9 F$Sleep        let system settle
*************************************************************************
 ldd #0             find out about current screen using stock OS-9
 std <buffer
 leax >buffer,u
 tfr x,d
******************* change for >512K systems; stock OS-9 ****************
 ldx #$9b           was $9D changed to $9B for >512K systems RG
 pshs u
 leau >block,u      was block+1 RG
 ldy #3             was 1       RG
 os9 F$CpyMem
 puls u
 lda <block         was lsr <block+1
 ldb <block+2           lsr <block+1
 lsra
 rorb
 lsra
 rorb
 std <block        16bit number $9B*256+$9D divided by 4; result stored RG
 ldx #0
 stx <offset       save offset of window start in first block
 lda #4
 sta <number       store number of blocks in use

mapin
 ldx <block         get starting block number
 ldb <number        get number of blocks we want to map in
 pshs u             save u
 os9 F$MapBlk       map them into user space
 lbcs usage         exit if error
 tfr u,d            put u in d (u=address of first block)
 puls u             restore u
 addd <offset       add offset to d
 std <screen        save start of screen
 addd #BOTROW*160
 std <end           save end of screen
 
* Screen has been mapped in.  Ready to proceed.

 ldx <screen        get start of screen
 leax (BOTROW-11)*160+1,x
 stx <maxleft       save this
 leax 150,x         add 74 to get right side
 stx <maxright      save this, too
 leay invader,pcr   initialize multiple frame bad guy stuff
 sty <badguy        badguy points to first frame
 leay invader2,pcr  get address of second frame
 sty <badguy+2      badguy+2 points to second frame
 leay invader3,pcr  get address of third frame
 sty <badguy+4      badguy+4 points to third frame
 leay invader4,pcr  get address of fourth frame
 sty <badguy+6      badguy+6 points to fourth frame

* IFEQ QUICK
 ldd #$1b2b         GPLoad escape code
 std <buffer        store in first two bytes of buffer
 os9 F$ID           get process ID
 sta <pid           (GRP) save it
 lda #$AC           $AC=Allen C. (as opposed to $AD being Alan DeKok)
 sta <pid+1         (BFN) save it
 lda <path          merge fonts into system
 leax >buffer,u     point to buffer
 ldy #4             output escape header
 os9 I$Write
 leax font,pcr      then output the actual font data
 ldy #fontlen
 os9 I$Write
 ldb #$3a           1b3a = select font
 stb <buffer+1      1b still there, store after it
 leax >buffer,u
 ldy #4
 os9 I$Write
* ENDC

* Start out here.  Reset score/lives...

gamestart
 leax initscore,pcr initialize score/lives
 leay >dscore,u
 lda #scorelen+liveslen+levellen+shotlen
initit ldb ,x+
 stb ,y+
 deca
 bne initit

 clr <elevel        start out with no enemy level
 clr <elevel+1
 clr <round         start at round 0
 lda #BULLETS       init how many bullets we can fire
 sta <bullets
 clr <gofast

* Title screen stuff

 lbsr clearscreen
 lbsr drawscreen
 lbsr drawshields
 lda <path          write title screen
 leax title,pcr
 ldy #titlelen
 os9 I$Write

ck1
 lbsr getkey        get key
 cmpa #'q           is it q?
 lbeq shutdown      yes, goto shutdown
 cmpa #'j           is it j?
 bne ck2            no, check next
 sta <ctrltype      else flag as joystick in use
 bra ck3            exit this check
ck2 cmpa #'k        is it k?
 bne ck1            no, so start over
 clr <ctrltype      else flag as keyboard
ck3

**** Stuff done before each round

roundstart
 lda #MISSILES*2    initialize player missiles
 leay missiles,u
minit clr ,y+
 deca
 bne minit

 lda #BOMBS*2       initialize bombs
 leay bombs,u
binit clr ,y+
 deca
 bne binit

 lda #ENEMIES       initialize bad guys
 sta <buffer
 leax badguys,pcr   point x to initial location
 leay enemies,u     point y to new location data
einit ldd ,x++      grab initial location
 addd <screen       add screen offset
 addd #160*22+1     22 lines down (bottom of enemy)
 addd <elevel       further down the higher the level
 std ,y++           store it in new area
 dec <buffer        decrement counter
 bne einit          loop if not done (duh)

 leay >badguy,u     initialize frame pointer
 sty <pointer
 clr <aframe        set animation initial frame to 0

 clr <edir          clear direction (0=right)
 lda #EDELAY        initialize delay counter
 suba <gofast
 cmpa #1
 bhs itsokay
 lda #1             no faster than this.  period
itsokay
 sta <edelay
 sta <ecount
 clr <acount        clear animation counter
 inc <acount        then set to 1
 lda #COUNTER
 sta <counter

 lda #50
 sta <kills        start out with 50 enemies.  when 0, you won.

 clr <ufodir       initialize ufo stuff
 clr <ufowhen
 inc <ufodir
 lda #UFODELAY
 sta <ufodelay
 sta <ufocount
 ldx <screen
 stx <ufoleft
 stx <ufoloc
 leax 152,x
 stx <uforight
 ldx <screen        top left
 leax 160*11,x       11 lines down
 stx <toppart       store toppart location
 clr <ufobomb
 lda #BDELAY        enemy bomb delay stuff
 sta <bdelay
 sta <bcount        clear bomb counter

 lbsr screener
 bsr clearscreen    clear the screen
 bsr drawscreen     draw border and bottom
 lda <round         check round
 cmpa #10           are we at level 10?
 bls doshields      if level 10 or less, skip and draw shields
 suba #10           else subtract 10 from round (0-...)
 sta <gofast
 bra noshields
doshields
 bsr drawshields    draw shields
noshields
 lbsr showscore     display score
 lbsr showlives     display lives left
 lbsr showlevel     display current level

 ldx <maxleft       get left
 leax 76,x          move to center
 stx <locx          save initial ship location
 lbra moveleft      move left to make player be displayed initially (center!)

* Draw borders and bottom

clearscreen
 lda <path
 leax cls,pcr
 ldy #1
 os9 I$Write
 rts

drawscreen
 ldx <screen        draw border
* leax 160*10+159,x  start 10 rows down
 leax 160*10,x      start 10 rows down
 lda #LBORDER
 ldb #RBORDER
* ldb #BORDER
* ldd #%0110100101101001
*draw std ,x
draw sta ,x         draw left border
 stb 159,x          draw right border
 leax 160,x         move to next row
 cmpx end           are we at the end?
 bls draw           no, so go do more
 ldx <end           draw bottom (below end)
 leax 160,x
 lda #160           160 bytes across
 ldb #$33           2-pixels
bottom stb ,x+      store pixels
 deca               decrement counter
 bne bottom         if not 0, go do more
 rts

* Put shields on screen

drawshields
 pshs u             push u
 leau shields,pcr   point u to shield location data
 lda ,u+            get # of shields
worf
 pshs d             save d
 ldd ,u++           get shield location
 addd <screen       offset it with start of screen memory
 tfr d,x            put location in x
 puls d
 leay shield,pcr    point y to shield image data
 ldb ,y+            get shield size
doshield pshs d     save d again
 ldd ,y++
 std ,x
 ldd ,y++
 std 2,x
 ldd ,y++
 std 4,x

 ldd ,y++
 std 6,x
 ldd ,y++
 std 8,x
 ldd ,y++
 std 10,x

 leax 160,x
 puls d             restore d again
 decb
 bne doshield
 deca
 bne worf
 puls u,pc

* Actual game code begins here...

game
* lda <zoomode
 tst <zoomode
 bne awake
 ldx #2             snooze for 2 ticks (otherwise way too fast!)
 os9 F$Sleep
awake

* Check lives remaining

 ldd <lives         get lives
 cmpd #$3030        is it [00] ascii?
 lbeq gameover      if yes, gameover

* Move missiles, perform collision w/enemies and ufo, etc.

 inc <firecount
 lda #MISSILES      move missiles
 leay missiles,u    point x to start of missile packet
mloop ldx ,y++      get first missile location
 lbeq mskip         if 0, no missile to fire
 clr ,x             erase missile
 leax -160,x        move missile up
 cmpx screen        is it at top of screen?
 lbls mreset        if so, reset
 ldb ,x             find out what is there
 bne zilch          if something, check it
 lbra mcont         otherwise continue
zilch
 cmpx <toppart      is missile in ufo area?
 bls hitufo         yeah. nuke the commie
 pshs y             save y
 ldb #ENEMIES       loop through all enemies
 leay enemies,u     point y to missile packet
hitcheck
* here I need to add a loop to check the entire area of the enemy (maybe)
 cmpx ,y            compare missile location to enemy location
 bls nope           if less, no hit
 leax -8,x          move missile 8 left
 cmpx ,y            compare again
 bls gotcha         if so, got one...
 leax 8,x
nope leay 2,y
 decb
 bne hitcheck       keep checking
 puls y             if done, restore y
 lbra missed        and go to miss
gotcha leax 4,x
 pshs a,x,u         clear the enemy off the screen
 lda #12
 ldx ,y             get baddie location
 leax 1,x
 ldu #0
 stu ,y
eraser stu ,x
 stu 2,x
 stu 4,x
 stu 6,x
 leax -160,x
 deca
 bne eraser

 lda <edelay        get current delay
 beq dontspeed      if 0, cannot go any faster to skip
 dec <counter       otherwise decrement counter
 bne dontspeed      if not 0, not ready to go faster
 lda #COUNTER       otherwise reset counter
 sta <counter
 dec <edelay        and set to go faster
 bne dontspeed      if not 0, go on
 inc <edelay        else make sure it doesn't get to 0
dontspeed
 lda <path          make sound (boom)
 ldb #$98
 ldx #$3f01
 ldy #3800
 os9 I$SetStt
 puls a,x,u
 puls y
 dec <kills         decrement kills
 lbeq nextround     if 0, we won...
 lbsr up10          else update score
 bra mreset

hitufo
 pshs u,x
 clr <ufodir        clear direction (not moving)
 ldx <ufoloc        get location
 ldu <ufoleft       get original location
 stu <ufoloc        reset location
 ldb #10
 ldu #0
 leax 1,x           clear ufo
ufocls stu ,x
 stu 2,x
 stu 4,x
 stu 6,x
 leax 160,x
 decb
 bne ufocls
 puls u,x
 lbsr up100         increment score
 pshs a,b,x,y       sound (bye bye mother)
 lda <path
 ldb #$98
 ldx #$3f02
 ldy #3850
 os9 I$SetStt
 puls a,b,x,y

 bra mreset

missed
 lsl ,x             take chunk outta shield
 lsl ,x
 lsl ,x
 lsl ,x
 lsr 1,x
 lsr 1,x
 lsr 1,x            cool...
 lsr 1,x
mreset
 ldx #0
 stx -2,y           reset missile to 0
 bra mskip
mcont ldb #$03      1.04 use ship colors
 stb ,x             put shot on screen
 stx -2,y
mskip deca          decrement counter
 lbne mloop         if not 0, more missiles to check for

* Enemy Bombs

 lda #BOMBS
 leay bombs,u
bombloop ldx ,y     get bomb location
 beq bombdrop       if 0, bomb not dropping - drop one
 clr ,x             erase old bombs
 leax 160,x          move it down
 ldb ,x             find out what is at bomb location
 bne bombhit        if not 0, we hit somethin'
 cmpx end           at end?
 bls bombcont       no, continue
bombreset
 ldx #0             else
 stx ,y             reset bomb
 bra bombskip
bombhit
 clr ,x
 cmpx <maxleft
 lbhs bombkill
 bra bombreset
bombkill
 ldx #0             reset bomb
 stx ,y
 lbra hitplayer     and kill player <g>
bombdrop
 dec <bcount        decrement bomb counter
 bne bombskip
 lda <bdelay
 sta <bcount
 pshs x,y
 leay enemies+(ENEMIES-1)*2,u
 ldb #ENEMIES
 lda <acount        *hack, hack, hack
 lsla
 lsla
* lsla
 beq droploop
hohum leay -2,y     for the life of me, I don't remember what this does
 deca
 bne hohum
droploop
 ldx ,--y           get enemy position
 beq dropcont       if 0, no enemy to drop bomb from...duh
 ldy 2,s
 leax 4,x           add four to bomb position (center of enemy)
 stx ,y
 ldx ,s             faster than puls x which we no longer will need
 leas 4,s           pop x,y
 bra bombend
dropcont decb
 bne droploop
 puls x,y
 bra bombskip
bombcont
 ldb #$03           1.04 use white
 stb ,x
 stx ,y
bombskip leay 2,y
 deca
 bne bombloop
bombend

* Service UFO bomb

 lda <ufobomb       check bomb
 beq ufobset        no bomb, skip and drop
 ldx <ufobloc       get bomb location
 clr ,x             erase old bomb
 leax 320,x         move bomb down
 ldb ,x             check what is at bomb location
 bne ufobhit
 cmpx <end
 bls ufodrop
ufobreset
 clr <ufobomb       else reset bomb
 bra ufostuff       do ufo stuff
ufobhit
 cmpx <maxleft      is it at bottom of screen?
 lbhs ufokill       yeah, musta hit player
 bra ufodrop
ufokill
 clr <ufobomb       reset ufo bomb
 lbra hitplayer      kill player
ufobset
 lda <ufodir        is ufo moving?
 beq ufostuff       no, so skip this...
 ldx <ufoloc        get ufo location
 leax (BOTROW-11)*160+2,x    move to same row as player
 cmpx <locx         same spot?
 bne ufostuff       nope, don't drop
 ldx <ufoloc        get ufo location
 leax 160*11+5,x    move down 11 lines and over 5 (center of UFO)
 inc <ufobomb
ufodrop
 lda #$ef           draw bomb (using ufo colors) 1.04
 sta ,x
 stx <ufobloc       update location
ufostuff
 lda <ufodir        is ufo moving (1)
 bne ufogo          not 0, so yes it is. go
 dec <ufowhen       else decrement "when" counter
 bne ufoskip        not 0? no ufo. skip
 inc <ufodir        else increment (start) the ufo
ufogo
 dec <ufocount      decrement counter
 bne ufoskip        not 0, so don't move
 lda <ufodelay      otherwise reset counter
 sta <ufocount
 leay ufo,pcr       point to ufo data
 lda ,y+            get size
 ldx <ufoloc        get location
 leax 1,x           move right
 cmpx <uforight     is at far right?
 bne ufocont        no, continue
 pshs u             else erase entire ufo
 ldu #0
ufoclear stu ,x
 stu 2,x
 stu 4,x
 stu 6,x
 leax 160,x
 deca
 bne ufoclear
 puls u
 ldx <ufoleft       reset ufo to start position
 stx <ufoloc
 clr <ufodir        make ufo no move
 lda <acount        *hack, hack, hack
 sta <ufodelay
 bra ufoskip
ufocont
 stx <ufoloc        update location
 pshs u
ufoloop clr ,x     draw ufo
 ldu ,y++
 stu 1,x
 ldu ,y++
 stu 3,x
 ldu ,y++
 stu 5,x
 ldu ,y++
 stu 7,x
 leax 160,x
 deca
 bne ufoloop
 puls u
ufoskip

* Take care of enemies...

animcheck
 dec <acount        check to see if we need to update animation frame
 bne skipanim
 lda #ADELAY
 sta <acount

 lda <path          We'll stick keyboard check in here...
 ldb #1
 os9 I$GetStt
 bcs nokeys         no, skip
 leax >buffer,u     else read character into buffer
 ldy #1
 os9 I$Read
 lda <buffer        get character from buffer
 cmpa #'q           quit from game
 lbeq gameover
 tst <cheatmode     can we cheat?
 beq nocheating
 cmpa #'*
 lbeq nextround
nocheating
 cmpa #'p
 bne nokeys
 lda <path
 leax pause,pcr
 ldy #pauselen
 os9 I$Write
 lbsr getkey
 lbsr showlevel
* lbsr showshots
nokeys

* 1.04 reverse animation based on direction
* lda <edir          check invader direction
* bne animright      if not 0, moving right
* dec <aframe        decrement frame
* lda <aframe        load frame number in to A
* cmpa #255          rolled over?
* beq xxx1           yes, go to handle
* ldx <pointer       get pointer to invader
* leax -2,x          decrement
* stx <pointer       save it back
* bra yyy            go to continuen
*xxx1
* lda #3             load last frame #3
* sta <aframe        update it
* leax >badguy+6,u   point to #3 badguy
* stx <pointer       update it
* bra yyy            skip the rest

animright
 inc <aframe        BRUTE FORCED to toggle through animation frames
 lda <aframe
 cmpa #EFRAMES      if frame > number of frames
 beq xxx            go to reset it 
 ldx <pointer       else get current pointer to frame
 leax 2,x           increment to next pointer
 stx <pointer       update it
 bra yyy            skip the rest
xxx
 clr <aframe        reset frame to 0
 leax >badguy,u     * outside of 128 bytes in dp (see BUG)
 stx <pointer       update reset frame pointer
yyy

skipanim
 dec <ecount        decrement enemy movement counter
 bne check2         if not 0, not time to move it
 bra gohere
check2
 ldb <acount        check to see if animation update required
 cmpb #ADELAY
 lbne ebypass

gohere
 lda #ENEMIES       get number of baddies
 leay enemies,u     point y to enemy location packet
eloop ldx ,y++      get location of baddie
 beq eskip          if 0, no baddie to draw
 ldb <ecount        check if we are moving
 bne spam2          if not 0, not moving so just display
 ldb <edir          get direction
 beq right
 leax -1,x
 bra spam
right leax 1,x      move to the right
spam stx -2,y       update position
spam2
 pshs u,y
 ldy [pointer]
 ldb ,y+            get size
eloop2 clr ,x
 ldu ,y++
 stu 1,x
 ldu ,y++
 stu 3,x
 ldu ,y++
 stu 5,x
 ldu ,y++
 stu 7,x
 clr 9,x
 leax -160,x
 decb
 bne eloop2
 puls u,y
eskip deca          decrement counter
 bne eloop          if more to draw, go do it again.  else done
 
 ldb <ecount
 lbne ebypass
 ldb <edelay
 stb <ecount

 lda <path          make sound (enemies moving)
 ldb #$98
 ldx #$3f00
 ldy #3000
 os9 I$SetStt

 lda <edir          get direction
 beq addpos         if 0, moving right...

 lda #ENEMIES
 leay enemies,u 
checkleft ldx ,y++
 ldb -1,x
 cmpb #LBORDER      1.04 check against new value
 beq makepos
 deca
 bne checkleft
 bra ebypass

addpos
 lda #ENEMIES
 leay enemies,u
checkright ldx ,y++
 ldb 10,x           get byte from there
 cmpb #RBORDER      1.04 check against new value
 beq makeneg        if border, must be wall
 deca
 bne checkright
 bra ebypass
makepos
 clr <edir         clear pos (make move right)
 bra movedown
makeneg
 inc <edir

movedown
 lda #ENEMIES       scroll through enemies
 leay enemies,u     point to enemy packet
mdloop ldx ,y
 beq mdskip

 ldb #12            clear enemy before moving location down... hey, it works!
 pshs u
 ldu #0
del stu 1,x
 stu 3,x
 stu 5,x
 stu 7,x
 leax -160,x
 decb
 bne del
 leax 12*160,x
 puls u
 
 leax 160*6,x
 cmpx <locx         are they at bottom of screen yet?
 lbhs gameover      if so, game over
 stx ,y
mdskip leay 2,y
 deca
 bne mdloop

 lda <path           make sound (down)
 ldb #$98
 ldx #$3f02
 ldy #3200
 os9 I$SetStt
ebypass

********** End of Move Enemy Routine *********

* Check for controller stuff

 tst <ctrltype      check controller typer
 bne joystick       if not 0, must be using joystick/mouse
 
 ldb #$27           KEYBOARD CHECK
 os9 I$GetStt
 cmpa #0            if 0, no key pressed
 lbeq moveskip       so skip

 bita #%10000000    space bar
 bne fire
 bita #%00100000    left arrow
 bne moveleft
 bita #%01000000    right arrow
 lbne moveright
 lbra game           neither, so start over

joystick
 lda <path          READ JOYSTICK
 ldb #$13           SS.JOY
 ldx #1             left port
 os9 I$GetStt
 tsta               check fire button
 bne fire
 cmpx #10
 bls moveleft
 cmpx #54
 bhs moveright
 lbra game

fire lda <firecount
 cmpa #FIRESPEED    are we ready to fire?
 lbls moveskip      no, so don't
 clr <firecount     else reset counter
 lda <bullets
 leay missiles,u    point y to missile data
floop ldx ,y++      get location of missile
 cmpx #0            if location is 0, missile available to fire
 beq fireit         so fire it
 deca               decrement counter
 bne floop          not 0? check for more missiles
 lbra moveskip      else, done
fireit ldx <locx    get player location
 leax -157,x        position above center of ship
 stx -2,y           save missile location

 lda <path          make sound (fire)
 ldb #$98
 ldx #$3f00
 ldy #3800
 os9 I$SetStt

 lbra game

moveleft
 ldx <locx          get current location
 cmpx <maxleft      are we already at maxleft?
 bls moveskip       if so, skip
 leax -1,x          otherwise move left
 stx <locx          update location
 leay ship,pcr      point y to ship data
 lda ,y+            get size
 pshs u
mleft ldu ,y++      heh heh...
 stu ,x
 ldu ,y++
 stu 2,x
 ldu ,y++
 stu 4,x
 ldu ,y++
 stu 6,x
 clr 8,x
 leax 160,x
 deca
 bne mleft
 puls u
 bra moveskip
moveright ldx <locx get current location
 cmpx <maxright     are we already at maxright?
 bhs moveskip       if so, skip
 leax 1,x
 stx <locx
 leax -1,x          don't ask...
 leay ship,pcr      point y to ship data
 lda ,y+            get size
 pshs u
mright clr ,x
 ldu ,y++
 stu 1,x
 ldu ,y++
 stu 3,x
 ldu ,y++
 stu 5,x
 ldu ,y++
 stu 7,x
 leax 160,x
 deca
 bne mright
 puls u
moveskip
 lbra game          go back and do it all again

* Player blasted...

hitplayer
 lda #8             8 times...
dieloop
 ldy <locx          get player location
 ldb #12
killship
 lsr ,y
 lsl 1,y
 lsr 2,y
 lsl 3,y
 lsr 4,y
 lsl 5,y
 lsr 6,y
 lsl 7,y
 lsr 8,y
 leay 160,y
 ldx #1
 os9 F$Sleep
 decb
 bne killship
 pshs a,b,x,y       sound (die, die, die)
 lda <path
 ldb #$98
 ldx #$3f00
 ldy #1000
 os9 I$SetStt
 puls a,b,x,y
 deca
 bne dieloop

 bsr declives       decrement lives

 ldx <maxleft
 leax 76,x          go back to 1 right of center
 stx <locx          save initial ship location
 lbra moveleft      display player

* Increase score

up10
 pshs a
 inc <score+3
 lda <score+3
 cmpa #'9
 bls upexit
 lda #'0
 sta <score+3
 puls a
up100
 pshs a
 inc <score+2
 lda <score+2
 cmpa #'9
 bls upexit
 lda #'0
 sta <score+2

 inc <score+1       up1000
 lda <score+1
 cmpa #'9
 bls upexit
 lda #'0
 sta <score+1

 inc <score         up10000
 lda <score
 cmpa #'9
 bls upexit
 lda #'0
 sta <score
upexit
 puls a

showscore
 pshs a,x,y
 lda <path
 leax >dscore,u
 ldy #scorelen
 os9 I$Write
 puls a,x,y,pc

* Decrease lives

declives
 lda <lives         check lives
 cmpa #'0           over 10?
 bls dec1           no, goto dec1
 dec <lives         else decrement 10s
 lda #'9            set 1s to 9
 sta <lives+1       update
 bra decexit        showlives
dec1
 lda <lives+1       get 1s
 cmpa #'0           is it 0?
 beq decexit        yeah, showlives
 dec <lives+1       else decrement
decexit
 lda <bullets       check bullets
 cmpa #2            at least one?
 bls nodec          no, can't dec
 dec <bullets       else decrement bullets
 dec <shots
 bsr showlevel
nodec

showlives
 pshs a,x,y
 lda <path
 leax >dlives,u
 ldy #liveslen
 os9 I$Write
 puls a,x,y,pc

showlevel
 lda <path
 leax >dlevel,u
 ldy #levellen+shotlen
 os9 I$Write
 rts

screener
 lda #4
screen1
 ldx <screen
screen2 lsr ,x+
 lsr ,x+
 cmpx <end
 bls screen2
 deca
 bne screen1
 rts

nextround
 inc <round         increment round pointer
 inc <level
 lda <round
 cmpa #10
 bhs skipdown
 ldd <elevel
 addd #160*6         6 rows lower next round
 std <elevel
skipdown
 lda <bullets       how many bullets can we fire?
 cmpa #MISSILES     are we already at max?
 bhs miskip         yeah, can't fire any more
 inc <bullets       otherwise increment bullets
 inc <shots
miskip
 lbra roundstart

gameover
 lda <path
 leax overmsg,pcr
 ldy #overmsglen
 os9 I$Write
 lbsr getkey
 lbsr screener
 lbra gamestart

shutdown
 lbsr screener
* IFEQ QUICK
 ldd #$1b2a         KilBuf escape header
 std <buffer        store it in buffer
 clr <pid+1         group 0 means bye bye fonts
 lda <path
 leax >buffer,u
 ldy #4
 os9 I$Write        kill font buffer...
* ENDC

 ldb <number        get number of blocks
 pshs u             save u
 ldu <block         get starting block number
 os9 F$ClrBlk       clear blocks from user space
 puls u
 lda #StdIn
 os9 I$Close
 lda #StdOut
 os9 I$Close
 lda <oldpath
 os9 I$Dup
 lda <oldpath
 os9 I$Dup
 lda #StdIn
 ldy #2
 leax select,pcr
 os9 I$Write
 lbra exit

getkey pshs b,x,y   save regs
gobble
 lda <path          gobble any waiting chars in buffer
 ldb #1
 os9 I$GetStt       check to see if character was in buffer
 bcs getit          if not, buffer clear.  no go check
 leax >buffer,u     else gobble what is there
 ldy #1
 os9 I$Read
 bra gobble
getit
 ldx #10            don't hog the cpu
 os9 F$Sleep
* tst <ctrltype      using joystick?
* beq keycheck       if 0, just check keyboard
 lda <path          else check for button press
 ldb #$13
 ldx #1
 os9 I$GetStt
 tsta               button pressed?
 beq keycheck       no, check for keys
 lda #'j            else load with j
 bra keyreturn      exit
keycheck
 lda <path          check for keyboard
 ldb #1
 os9 I$GetStt
 bcs getit          nothing waiting, go back
 leax >buffer,u
 ldy #1
 os9 I$Read
 lda <buffer        get character read in reg. a
keyreturn
 puls b,x,y,pc      restore regs

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

window fcc "/W"
 fcb $d

cls fcb $c          clear screen byte

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

overmsg fcb $2,$20+11,$20+23
 fcc " /) GAME OVER! (\ "
overmsglen equ *-overmsg

pause fcb $2, $20+11,$20+23
 fcc " /) PAUSED... (\ "
pauselen equ *-pause

initscore fcb $02,$20+1,$20+23
 fcc "00000"
scorelen equ *-initscore

initlives fcb $02,$20+31,$20+23
 fcc "Lives 03"
liveslen equ *-initlives

initlevel fcb $2,$20+11,$20+23
 fcc "Round A"
levellen equ *-initlevel

initshots
* fcb $2,$20+21,$20+23
 fcc "   Power C"
shotlen equ *-initshots

makewin fcb $1b,$20,$8,0,0,40,24,3,0,0          make 40 column gfx window
 fcb $1b,$31,00,00,$1b,$31,01,7                 set rgb palette slot colors
 fcb $1b,$31,02,56,$1b,$31,03,63                ship (0-3)
 fcb $1b,$31,04,$00,$1b,$31,05,$06              invader colors (4-7)
 fcb $1b,$31,06,$30,$1b,$31,07,$36              
 fcb $1b,$31,08,$00,$1b,$31,09,$09              shield colors (8-11)
 fcb $1b,$31,10,$05,$1b,$31,11,$08
 fcb $1b,$31,12,$00,$1b,$31,13,$05              ufo colors (12-15)
 fcb $1b,$31,14,$28,$1b,$31,15,$3f
 fcb $05,$20                                    turn off cursor
select fcb $1b,$21                              select
mwinlen equ *-makewin

setmono
 fcb $1b,$31,00,$00,$1b,$31,01,$10              monochrome colors
 fcb $1b,$31,02,$20,$1b,$31,03,$3f
 fcb $1b,$31,04,$00,$1b,$31,05,$10              monochrome invader
 fcb $1b,$31,06,$20,$1b,$31,07,$3f
 fcb $1b,$31,08,$00,$1b,$31,09,$10              monochrome shield
 fcb $1b,$31,10,$20,$1b,$31,11,$3f
 fcb $1b,$31,12,$00,$1b,$31,13,$10              monochrome ufo
 fcb $1b,$31,14,$20,$1b,$31,15,$3f
monolen equ *-setmono

badguys fdb 0,10,20,30,40,50,60,70,80,90
 fdb W+0,W+10,W+20,W+30,W+40,W+50,W+60,W+70,W+80,W+90
 fdb X+0,X+10,X+20,X+30,X+40,X+50,X+60,X+70,X+80,X+90
 fdb Y+0,Y+10,Y+20,Y+30,Y+40,Y+50,Y+60,Y+70,Y+80,Y+90
 fdb Z+0,Z+10,Z+20,Z+30,Z+40,Z+50,Z+60,Z+70,Z+80,Z+90

ship fcb 12         *0,1,2,3*
 fcb $00,$00,$00,$03,$00,$00,$00,$00
 fcb $00,$00,$00,$32,$10,$00,$00,$00
 fcb $00,$00,$00,$32,$10,$00,$00,$00
 fcb $00,$22,$22,$22,$22,$22,$20,$00
 fcb $00,$00,$00,$32,$10,$00,$00,$00
 fcb $00,$00,$00,$32,$10,$00,$00,$00
 fcb $00,$22,$22,$22,$22,$22,$20,$00
 fcb $00,$00,$03,$22,$11,$00,$00,$00
 fcb $00,$00,$03,$22,$11,$00,$00,$00
 fcb $00,$33,$33,$22,$21,$11,$10,$00
 fcb $33,$32,$22,$22,$22,$21,$11,$10
 fcb $32,$22,$22,$22,$22,$22,$11,$10

invader fcb 12      *4,5,6,7*
 fcb $50,$50,$50,$50,$50,$50,$50,$50
 fcb $00,$00,$77,$77,$77,$70,$00,$00
 fcb $00,$76,$66,$66,$66,$67,$70,$00
 fcb $07,$66,$66,$66,$66,$66,$67,$00
 fcb $76,$66,$66,$66,$66,$66,$66,$70
 fcb $76,$66,$66,$66,$66,$66,$66,$70
 fcb $76,$66,$66,$66,$66,$66,$66,$70
 fcb $76,$66,$66,$66,$66,$66,$66,$70
 fcb $76,$66,$66,$66,$66,$66,$66,$70
 fcb $07,$66,$66,$66,$66,$66,$67,$00
 fcb $00,$77,$66,$66,$66,$67,$70,$00
 fcb $00,$00,$77,$77,$77,$70,$00,$00

invader2 fcb 12
 fcb $00,$05,$05,$05,$05,$05,$00,$00
 fcb $00,$00,$07,$76,$66,$00,$00,$00
 fcb $00,$00,$76,$66,$55,$50,$00,$00
 fcb $00,$07,$66,$66,$55,$55,$00,$00
 fcb $00,$07,$66,$66,$65,$55,$00,$00
 fcb $00,$07,$66,$66,$65,$55,$00,$00
 fcb $00,$07,$66,$66,$65,$55,$00,$00
 fcb $00,$07,$66,$66,$65,$55,$00,$00
 fcb $00,$07,$66,$66,$65,$55,$00,$00
 fcb $00,$07,$66,$66,$65,$55,$00,$00
 fcb $00,$00,$76,$66,$55,$50,$00,$00
 fcb $00,$00,$07,$76,$55,$00,$00,$00

invader3 fcb 12
 fcb $00,$00,$00,$50,$50,$00,$00,$00
 fcb $00,$00,$00,$07,$00,$00,$00,$00
 fcb $00,$00,$00,$07,$00,$00,$00,$00
 fcb $00,$00,$00,$76,$50,$00,$00,$00
 fcb $00,$00,$00,$76,$50,$00,$00,$00
 fcb $00,$00,$00,$76,$50,$00,$00,$00
 fcb $00,$00,$00,$76,$50,$00,$00,$00
 fcb $00,$00,$00,$76,$50,$00,$00,$00
 fcb $00,$00,$00,$76,$50,$00,$00,$00
 fcb $00,$00,$00,$76,$50,$00,$00,$00
 fcb $00,$00,$00,$07,$00,$00,$00,$00
 fcb $00,$00,$00,$07,$00,$00,$00,$00

invader4 fcb 12
 fcb $00,$05,$05,$05,$05,$05,$00,$00
 fcb $00,$00,$06,$66,$77,$00,$00,$00
 fcb $00,$00,$55,$56,$66,$70,$00,$00
 fcb $00,$05,$55,$56,$66,$67,$00,$00
 fcb $00,$05,$55,$66,$66,$67,$00,$00
 fcb $00,$05,$55,$66,$66,$67,$00,$00
 fcb $00,$05,$55,$66,$66,$67,$00,$00
 fcb $00,$05,$55,$66,$66,$67,$00,$00
 fcb $00,$05,$55,$66,$66,$67,$00,$00
 fcb $00,$05,$55,$66,$66,$67,$00,$00
 fcb $00,$00,$55,$56,$66,$70,$00,$00
 fcb $00,$00,$05,$56,$77,$00,$00,$00

* 1.04 fixing shield graphic
shield fcb 16       *8,9,A,B*
 fcb $00,$99,$99,$99,$99,$99,$99,$99,$99,$99,$90,$00
 fcb $09,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$00
 fcb $99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$90
 fcb $99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$9A
 fcb $99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$9A
 fcb $9B,$BB,$BB,$BB,$BB,$BB,$99,$9B,$99,$BB,$B9,$9A
 fcb $9B,$99,$99,$99,$B9,$9B,$99,$9B,$9B,$99,$9B,$9A
 fcb $9B,$BB,$99,$99,$B9,$9B,$BB,$BB,$9B,$BB,$BB,$9A
 fcb $9B,$99,$99,$99,$B9,$9B,$99,$9B,$9B,$99,$9B,$9A
 fcb $9B,$BB,$BB,$99,$B9,$9B,$99,$9B,$9B,$99,$9B,$9A
 fcb $99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$9A
 fcb $99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$99,$9A
 fcb $99,$99,$AA,$AA,$AA,$AA,$AA,$AA,$AA,$A9,$99,$9A
 fcb $99,$9A,$00,$00,$00,$00,$00,$00,$00,$00,$99,$9A
 fcb $99,$A0,$00,$00,$00,$00,$00,$00,$00,$00,$09,$9A
 fcb $9A,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$9A
* __..__..__..__..__..__..
*  EEEEETTTTTH   H  AAA
*  E      T  H   H A   A
*  EEE    T  HHHHH AAAAA
*  E      T  H   H A   A
*  EEEEE  T  H   H A   A 

shields fcb 3
 fdb 150*160+20,150*160+74,150*160+128

ufo fcb 10          *c,d,e,f*
 fcb $0F,$00,$0E,$EE,$EE,$D0,$00,$F0
 fcb $00,$F0,$EF,$EE,$EE,$ED,$0F,$00
 fcb $00,$0E,$FE,$EE,$EE,$ED,$D0,$00
 fcb $00,$EE,$FE,$EE,$EE,$EE,$DD,$00
 fcb $00,$EE,$EE,$EE,$EE,$EE,$DD,$00
 fcb $FF,$FE,$EE,$EE,$EE,$EE,$DF,$FF
 fcb $00,$EF,$FF,$FF,$FF,$FF,$FD,$00
 fcb $00,$0E,$EE,$EE,$EE,$ED,$D0,$00
 fcb $00,$F0,$EE,$EE,$EE,$DD,$0F,$00
 fcb $0F,$00,$0E,$EE,$ED,$D0,$00,$F0

* IFEQ QUICK
font
 fcb $05,$00,$08,$00,$08,$04,$00 <- GPBufLoad Stuff
 fcb 0,87,81,119,20,23,0,0  * hidden stuff in the font! :)
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
 fcb 0,87,81,119,20,23,0,0
* 32 (space)
 fcb 0, 0, 0, 0, 0, 0, 0, 0
 fcb 16, 16, 24, 24, 24, 0, 24, 0
 fcb 102, 102, 204, 0, 0, 0, 0, 0
 fcb 68, 68, 255, 68, 255, 102, 102, 0
 fcb 24, 126, 64, 126, 6, 126, 24, 0
 fcb 98, 68, 8, 16, 49, 99, 0, 0
 fcb 62, 32, 34, 127, 98, 98, 126, 0
 fcb 56, 56, 24, 48, 0, 0, 0, 0
 fcb 12, 24, 48, 48, 56, 28, 12, 0
 fcb 48, 56, 28, 12, 12, 24, 48, 0
 fcb 0, 24, 36, 90, 36, 24, 0, 0
 fcb 0, 24, 24, 124, 16, 16, 0, 0
 fcb 0, 0, 0, 0, 0, 48, 48, 96
 fcb 0, 0, 0, 126, 0, 0, 0, 0
 fcb 0, 0, 0, 0, 0, 48, 48, 0
* 47 /
 fcb 2, 2, 4, 24, 48, 96, 96, 0
 fcb 126, 66, 66, 70, 70, 70, 126, 0
 fcb 8, 8, 8, 24, 24, 24, 24, 0
 fcb 126, 66, 2, 126, 96, 98, 126, 0
 fcb 124, 68, 4, 62, 6, 70, 126, 0
 fcb 124, 68, 68, 68, 126, 12, 12, 0
 fcb 126, 64, 64, 126, 6, 70, 126, 0
 fcb 126, 66, 64, 126, 70, 70, 126, 0
 fcb 62, 2, 2, 6, 6, 6, 6, 0
 fcb 60, 36, 36, 126, 70, 70, 126, 0
 fcb 126, 66, 66, 126, 6, 6, 6, 0
 fcb 0, 24, 24, 0, 24, 24, 0, 0
 fcb 0, 24, 24, 0, 24, 24, 48, 0
 fcb 6, 12, 24, 48, 28, 14, 7, 0
 fcb 0, 0, 126, 0, 126, 0, 0, 0
 fcb 112, 56, 28, 6, 12, 24, 48, 0
 fcb 126, 6, 6, 126, 96, 0, 96, 0
* 64
 fcb 60, 66, 74, 78, 76, 64, 62, 0
 fcb 60, 36, 36, 126, 98, 98, 98, 0
 fcb 124, 68, 68, 126, 98, 98, 126, 0
 fcb 126, 66, 64, 96, 96, 98, 126, 0
 fcb 124, 66, 66, 98, 98, 98, 124, 0
 fcb 126, 64, 64, 124, 96, 96, 126, 0
 fcb 126, 64, 64, 124, 96, 96, 96, 0
 fcb 126, 66, 64, 102, 98, 98, 126, 0
 fcb 66, 66, 66, 126, 98, 98, 98, 0
 fcb 16, 16, 16, 24, 24, 24, 24, 0
 fcb 4, 4, 4, 6, 6, 70, 126, 0
 fcb 68, 68, 68, 126, 98, 98, 98, 0
 fcb 64, 64, 64, 96, 96, 96, 124, 0
 fcb 127, 73, 73, 109, 109, 109, 109, 0
 fcb 126, 66, 66, 98, 98, 98, 98, 0
 fcb 126, 66, 66, 98, 98, 98, 126, 0
 fcb 126, 66, 66, 126, 96, 96, 96, 0
 fcb 126, 66, 66, 66, 66, 78, 126, 0
 fcb 124, 68, 68, 126, 98, 98, 98, 0
 fcb 126, 66, 64, 126, 6, 70, 126, 0
 fcb 126, 16, 16, 24, 24, 24, 24, 0
 fcb 66, 66, 66, 98, 98, 98, 126, 0
 fcb 98, 98, 98, 102, 36, 36, 60, 0
 fcb 74, 74, 74, 106, 106, 106, 126, 0
 fcb 66, 66, 66, 60, 98, 98, 98, 0
 fcb 66, 66, 66, 126, 24, 24, 24, 0
 fcb 126, 66, 6, 24, 96, 98, 126, 0
* 91 [
 fcb 126, 64, 64, 96, 96, 96, 126, 0
* 92 \
 fcb 64,64,32,24,12,6,6,0
* 93 ]
 fcb 126, 2, 2, 6, 6, 6, 126, 0
* 94 up arrow
 fcb 24,52,98,0,0,0,0,0
* 95 _
 fcb 0, 0, 0, 0, 0, 0, 0, 255
* 96 `
 fcb 96, 48, 0, 0, 0, 0, 0, 0
* 97 a
 fcb 0, 0, 62, 2, 126, 98, 126, 0
 fcb 64, 64, 126, 70, 70, 70, 126, 0
 fcb 0, 0, 126, 66, 96, 98, 126, 0
 fcb 2, 2, 126, 66, 70, 70, 126, 0
 fcb 0, 0, 124, 68, 124, 98, 126, 0
 fcb 62, 34, 32, 120, 48, 48, 48, 0
 fcb 0, 0, 126, 66, 98, 126, 2, 62
 fcb 64, 64, 126, 66, 98, 98, 98, 0
 fcb 16, 0, 16, 16, 24, 24, 24, 0
 fcb 0, 2, 0, 2, 2, 2, 98, 126
 fcb 96, 96, 100, 68, 126, 70, 70, 0
 fcb 16, 16, 16, 16, 24, 24, 24, 0
 fcb 0, 0, 98, 126, 74, 106, 106, 0
 fcb 0, 0, 126, 66, 98, 98, 98, 0
 fcb 0, 0, 126, 66, 98, 98, 126, 0
 fcb 0, 0, 126, 66, 66, 126, 96, 96
 fcb 0, 0, 126, 66, 78, 126, 2, 2
 fcb 0, 0, 124, 96, 96, 96, 96, 0
 fcb 0, 0, 126, 64, 126, 6, 126, 0
 fcb 16, 16, 126, 16, 24, 24, 24, 0
 fcb 0, 0, 66, 66, 98, 98, 126, 0
 fcb 0, 0, 98, 98, 98, 36, 24, 0
 fcb 0, 0, 66, 74, 106, 126, 36, 0
 fcb 0, 0, 98, 126, 24, 126, 98, 0
 fcb 0, 0, 98, 98, 98, 36, 24, 112
 fcb 0, 0, 126, 108, 24, 50, 126, 0
 fcb 14, 24, 24, 112, 24, 24, 14, 0
 fcb 24, 24, 24, 0, 24, 24, 24, 0
 fcb 112, 24, 24, 14, 24, 24, 112, 0
 fcb 50, 126, 76, 0, 0, 0, 0, 0
 fcb 102, 51, 153, 204, 102, 51, 153, 204
* fcb $1b,$3a,$c8,$ac display font
fontlen equ *-font
* ENDC

 endsect
