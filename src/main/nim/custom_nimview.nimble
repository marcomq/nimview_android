# This specific file is based on https://github.com/yglukhov/nimpy/blob/master/nimpy.nimble

version     = "0.1.0"
author      = "Marco Mengelkoch"
description = "Nim / C library to run webview with HTML/JS as UI"
license     = "MIT"

# Dependencies
# you may skip jester, nimpy and webview when compiling with nim c -d:just_core

# Currently, Webview requires gcc and doesn't work with vcc or clang

requires "nim >= 0.17.0", "jester >= 0.5.0", "nimpy >= 0.1.1", "webview == 0.1.0"
let vueDir = "../vue"
let application = "custom_nimview"
bin = @[application]
let mainApp = application & ".nim"
let libraryFile =  mainApp

import oswalkdir, os, strutils  
  
proc execCmd(command: string) = 
  when defined(windows): 
    exec "cmd /c \"" & command & "\""
  else:
    exec command

proc buildC() = 
  ## creates python and C/C++ libraries
  
  let stdOptions = "--header:" & application & ".h --app:lib -d:just_core -d:noSignalHandler -d:danger -d:release -d:androidNDK --os:android -d:noMain --noMain:on --threads:on "
 
  rmDir("./../cpp/arm64-v8a")
  selfExec " cpp -c " & stdOptions & "--cpu:arm64 --nimcache:./../cpp/arm64-v8a " & mainApp
  rmDir("./../cpp/armeabi-v7a")
  selfExec " cpp -c " & stdOptions & " --cpu:arm --nimcache:./../cpp/armeabi-v7a " & mainApp
  rmDir("./../cpp/x86")
  selfExec " cpp -c " & stdOptions & " --cpu:i386 --nimcache:./../cpp/x86 " & mainApp
  rmDir("./../cpp/x86_64")
  selfExec " cpp -c " & stdOptions & " --cpu:amd64 --nimcache:./../cpp/x86_64 " & mainApp
  let oldDir = thisDir() 
  cd vueDir
  execCmd("npm install")
  cd oldDir
  execCmd("npm run build --prefix " & vueDir)
  cpFile("../../nimview/backend-helper.js", vueDir & "/dist/backend-helper.js")
  cpDir(vueDir & "/dist", "../assets")

task nimToC, "Build Libs":
  buildC()

task serve, "Serve NPM":
  execCmd("npm run serve --prefix " & vueDir)
