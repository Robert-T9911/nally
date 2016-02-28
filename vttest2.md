# Introduction #

Continuing [previous page](http://code.google.com/p/nally/wiki/vttest).

# Implementations #

  1. VT102 feature insert (character) mode, 80 columns <img src='http://farm2.static.flickr.com/1193/3170277256_8759f88a97_o.png' width='640' />
  1. VT102 feature delete character, 80 columns <img src='http://farm2.static.flickr.com/1010/3170277276_e87a49af85_o.png' width='640' />
  1. VT102 feature Right column staggered by 1 (normal chars), 80 columns <img src='http://farm2.static.flickr.com/1125/3169447253_9e3e525686_o.png' width='640' />
  1. VT102 feature Insert/Delete Line within scroll range <img src='http://farm2.static.flickr.com/1176/3173285859_6892b64b86_o.png' width='640' />
  1. VT102 ANSI Inser Character Test ^[[2@ <img src='http://farm4.static.flickr.com/3257/3174120476_3e2870e199_o.png' width='640' />
  1. VT102 Testing Status Report response <img src='http://farm2.static.flickr.com/1120/3174222510_654030747a_o.png' width='640' />
  1. VT102 Report "What are you?" currently only replies vt102 but added a flag for future used. <img src='http://farm2.static.flickr.com/1078/3174222558_abf4d83340_o.png' width='640' />

# Details #

  * We are not interested in 132 column mode in Nally right now.
  * Tabulation Stop has not yet been implemented in Nally.