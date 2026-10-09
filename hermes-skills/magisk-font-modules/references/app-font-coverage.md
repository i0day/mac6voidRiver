# Which apps respect a system font module

Rule: a Magisk fonts.xml/TTF overlay only affects apps that resolve fonts through the Android framework (`Typeface.SANS_SERIF`, `fontFamily="sans-serif"`, CJK fallback). Three classes bypass it:

1. **Bundled-font apps** — ship TTF/OTF in `assets/fonts/` and load via `Typeface.createFromAsset`. Examples: WeChat (WeChatSansStd/SS, SF Pro, novelty fonts), QQ, many CN super-apps. Not safely replaceable — signature/integrity checks, ban risk. Do not attempt APK patching.
2. **Own-rendering-engine apps** — browsers (Firefox/Gecko, Chrome web content), some readers. They keep their own font stack. Fixable in-app: Firefox → Settings → Fonts → set default/serif/sans to the installed font's family name (e.g. `LXGW WenKai GB Screen`); optionally disable "allow sites to choose fonts" for full effect.
3. **Named-family requesters** — apps requesting `google-sans`/`google-sans-flex` resolve via `/product/etc/fonts_customization.xml`, not the patched `sans-serif` family. System UI (Settings, notifications, dialer, DocumentsUI, Messages) uses framework sans-serif and DOES change.

Diagnostic per app:
```
APK=$(adb -s <dev> shell pm path <pkg> | head -1 | sed 's/package://')
adb -s <dev> shell su -c "unzip -l $APK | grep -iE '\.(ttf|otf|ttc)'"
```
Any hits in assets/fonts/ = bundled-font app = module won't affect its text.

Quick test apps that DO show system font changes: Settings, Google Messages, Contacts, dialer, Termux (monospace module), any reader app using system fonts. Prefer these when demonstrating a font module worked.
