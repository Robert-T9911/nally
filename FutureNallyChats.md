# Target #
  * Plug-in architecture
  * Scriptable
  * UTF-8 support
  * Get most of vt100/xterm support
  * Scrollback
  * 變更預設值: 字型，顏色等設定成更合理。
  * 清理執行檔: header和nib沒清乾淨
  * 更改透明背景繪製方式：目前的實做不能說錯，但是有點不合理。

# Plug-Ins #
## feature ##
  * 可以針對 data arrive、click、double-click、mouse move 等事件來做事。
  * 可以取得目前畫面上的資料。
  * 可以傳送資料到連線的 object 上。
  * 可以針對特定站點做事情，如此就有 site hack。
  * 或是可以在 contextual menu 或者 menu bar 底下出現一個專區。contextual 應該要 context aware 出現消失，menu bar 要 auto disable。

## Issue ##
  * 有多個 plug-in 都對註冊同一事件時，要決定讓哪個做，或是都做要按照什麼順序做？

# UTF-8 #
決定了，以後所有進來 terminal 的資料都按照編碼轉成 unicode 處理。
要如何儲存呢？
  * 把 cell 的 storage 定義從 char 改成 unichar？
  * 沿用目前的 storage，只是 U+00FF 以下就只取 low byte 存進 char。U+0100以上就分別儲存在兩個 cell 中。目前的 doubleByte flag 仍可沿用。

# vt100/xterm/terminal #
  * g0/g1 ticket submitted
  * xterm ticket would be submitted after I tried to work on ignoring window title sequence (我們要做 window title 改變嗎...)
  * resizable geometry or geometric options and even full screen mode, also 長螢幕 support (alternative geometry negotiation seems to be part of telnet, but how can ssh did it?)
  * perhaps need to throttle comm speed..... wait until I can find something similar in GNUterminal.app or vte library....