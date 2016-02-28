# Introduction #

Here goes the roadmap of Nally (under discussion)

# Roadmap #
  1. [EXIF](ShowEXIF.md) - jjgod

# Release Note #
  * 1.4.2
  1. SSH 到 BBS 時關閉 X11 Forwarding。 - mjhsieh
  1. 修正半型處理中引發的重繪問題。 - mjhsieh
  1. 正確處理地址欄輸入的地址。 - mjhsieh
  1. 其他終端相關的相容性改進。(see [vttest](vttest.md) [vttest2](vttest2.md) [ncursetest](ncursetest.md)) (QKMJ 問題似乎是順便被解決了 ) - mjhsieh

  * 1.4.1
  1. (新增) 加入对保存预览图片的试验性支持。 - jjgod
  1. 修正 GBK 特定高字节 (0x9B) 处理问题。 - jjgod
  1. 将 GBK 中原映射到 PUA 的字符根据 Unicode 5.0 改为映射到 CJK Ext-A 区。 - jjgod
  1. 修正对光标处于窗口边界时的检查。(fayewong 报告) - jjgod
  1. 修正预览图片时部分内容被窗口标题栏覆盖的问题。(fayewong 报告) - jjgod

  * 1.4.0
  1. 修正 GBK 特定低字节处理问题。 - jjgod
  1. 加入对属于 GBK 但不属于 CP936 的 80 个汉字的支持。 - jjgod
  1. 修正背景色不能延伸到行末的问题。(Evan 报告) - jjgod
  1. 修正一些半透明背景绘制的问题。(fishy 报告) - jjgod
  1. 修正输入到窗口边沿光标判断的问题。(fayewong) - jjgod