# Introduction #

Using ncurses-5.7/test, you can have a lot of feature test, our goal is to mimic xterm's behavior as possible.

# Details #

Some tests that passed
  1. env TERM=xterm-color ./background.dSYM
  1. env TERM=xterm-color ./color\_set.dSYM
  1. env TERM=xterm-color ./dots.dSYM (be careful, this DoS your nally)
  1. env TERM=xterm-color ./dots\_mvcur.dSYM (be careful, this DoS your nally)
  1. env TERM=xterm-color ./echochar.dSYM (be careful, this DoS your nally)
  1. env TERM=xterm-color ./firework.dSYM
  1. ./firstlast.dSYM
  1. env TERM=xterm-color ./hanoi.dSYM
  1. ./railroad.dSYM
  1. env TERM=xterm-color ./rain.dSYM
  1. env TERM=xterm-color ./redraw.dSYM
  1. env TERM=xterm-color ./tclock.dSYM
  1. env TERM=xterm-color ./testaddch.dSYM
  1. env TERM=xterm-color ./worm.dSYM
  1. env TERM=xterm-color ./xmas.dSYM

Failed (g0/g1)
  1. cardfile
  1. gdc
  1. lrtest
  1. ncurses
  1. newdemo
  1. testcurs