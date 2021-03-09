# nimview_android
A Nim/Webview based helper to create Android applications with Nim/C/C++ and HTML/CSS

Android Implementation of [Nimview](https://github.com/marcomq/nimview)

This project uses Android Webview as UI layer. The back-end is supposed to be written in Nim, C/C++
or - if it doesn't need to be ported to other platforms - Kotlin or Java.
As the compilation process is slow, it would be recommended to write a web application with nimview or npm first and
then check the changes on Android later.

The nimview directory is a git subtree of https://github.com/marcomq/nimview. The steps performed were:
```
 git subtree add --prefix app/src/nimview https://github.com/marcomq/nimview.git main --squash
 git subtree pull --prefix app/src/nimview --squash  https://github.com/marcomq/nimview.git main
```
