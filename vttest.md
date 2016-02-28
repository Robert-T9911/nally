# Introduction #

VTTEST is a very useful application to demonstrate features of VT100 and related terminals. It can also be used to test the compatibility of terminal emulator. See [Page 2 for more](http://code.google.com/p/nally/wiki/vttest2)

# Implementations #

  1. Implemented response upon terminal type query, however Nally only replies it's a VT102.
  1. Properly ignoring "Selects G0 character" control command: ![http://lh3.ggpht.com/_83P-OanxqzA/STbgAI6cVWI/AAAAAAAAARQ/HYs82Rfc_Ak/s640/Picture%201.png](http://lh3.ggpht.com/_83P-OanxqzA/STbgAI6cVWI/AAAAAAAAARQ/HYs82Rfc_Ak/s640/Picture%201.png)
  1. Implemented `^[[K` to ease characters from cursor to the end of line.
  1. Implemented `^[#8` to fill the whole screen with E for alignment test.
  1. Cusor Movement Test 1: (backspace behavior) <img src='http://farm4.static.flickr.com/3292/3145320715_b4f1b41319_o.png' width='640' />
  1. Properly ignoring 132 column mode: `^[[?3h` and `^[[?3l`
  1. Cusor Movement Test 3: (autowrap, scroll within a range of row) <img src='http://farm4.static.flickr.com/3088/3146153232_162a358b25_o.png' width='640' />
  1. Cusor Movement Test 4: (and backspace inside control code) <img src='http://farm4.static.flickr.com/3127/3146153280_295d4191fb_o.png' width='640' />
  1. Cusor Movement Test 5: (I didn't do anything...) <img src='http://farm4.static.flickr.com/3266/3146153322_72864e2ac8_o.png' width='640' />
  1. Screen Feature Test 1: (Autowrap mode switching) <img src='http://farm4.static.flickr.com/3123/3158692193_1e0db6a740_o.png' width='640' />
  1. Screen Feature Test 3: (Screen reverse mode switching) <img src='http://farm4.static.flickr.com/3077/3161961856_23095a0b13_o.png' width='640' />
  1. Screen Feature Test 4: (Screen reverse mode switching) <img src='http://farm4.static.flickr.com/3110/3161961908_61744d421d_o.png' width='640' />
  1. Screen Feature Jump scroll down in row 12~13 <img src='http://farm4.static.flickr.com/3129/3162471803_865c1d6c4d_o.png' width='640' />
  1. Screen Feature Soft scroll down in row 12~13 <img src='http://farm4.static.flickr.com/3121/3162471759_cb5d1a75c2_o.png' width='640' />
  1. Screen Feature Soft scroll down in row 1~24 <img src='http://farm4.static.flickr.com/3095/3163304700_307f666a03_o.png' width='640' />
  1. Screen Feature Jump scroll down within row 1~24 <img src='http://farm4.static.flickr.com/3132/3162471839_883bb55977_o.png' width='640' />
  1. Screen Feature Graphic Rendition test pattern, dark background <img src='http://farm4.static.flickr.com/3127/3163304808_9d528aba0b_o.png' width='640' />
  1. Screen Feature Graphic Rendition test pattern, light background <img src='http://farm4.static.flickr.com/3086/3163304928_25e33d921a_o.png' width='640' />
  1. Screen Feature Origin mode test: row 23~24 <img src='http://farm4.static.flickr.com/3119/3162523221_5e2f4eee1f_o.png' width='640' />
  1. Screen Feature Origin mode test: resetting <img src='http://farm4.static.flickr.com/3115/3162523257_c9a40bae7a_o.png' width='640' />

# Details #

  * We are not interested in 132 column mode in Nally right now.
  * Tabulation Stop has not yet been implemented in Nally.