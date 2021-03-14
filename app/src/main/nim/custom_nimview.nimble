# This specific file is based on https://github.com/yglukhov/nimpy/blob/master/nimpy.nimble

version     = "0.1.0"
author      = "Marco Mengelkoch"
description = "Nim / C library to run webview with HTML/JS as UI"
license     = "MIT"

# Dependencies
# you may skip jester, nimpy and webview when compiling with nim c -d:just_core
# alternatively, you still can just skip webkit by compiling with -d:useServer

# Currently, Webview requires gcc and doesn't work with vcc or clang

requires "nim >= 0.17.0", "jester >= 0.5.0", "nimpy >= 0.1.1", "webview == 0.1.0", "nake >= 1.9.0"
const application = "custom_nimview"
bin = @[application]


