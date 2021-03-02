# This specific file is based on https://github.com/yglukhov/nimpy/blob/master/nimpy.nimble

version     = "0.1.0"
author      = "Marco Mengelkoch"
description = "Nim / C library to run webview with HTML/JS as UI"
license     = "MIT"

# Dependencies
# you may skip jester, nimpy and webview when compiling with nim c -d:just_core

# Currently, Webview requires gcc and doesn't work with vcc or clang

requires "nim >= 0.17.0", "jester >= 0.5.0", "nimpy >= 0.1.1", "webview == 0.1.0"
let uiDir = "../../nimview/examples/svelte"
let application = "custom_nimview"
bin = @[application]
let mainApp = application & ".nim"
let libraryFile =  mainApp

import oswalkdir, os, strutils  
  
let nimbleDir = parentDir(parentDir(system.findExe("nimble")))
var nimbaseDir = parentDir(nimbleDir) & "/lib"
if (not system.fileExists(nimbaseDir & "/nimbase.h")):
  nimbaseDir = parentDir(parentDir(system.findExe("makelink"))) & "/lib"
if (not system.fileExists(nimbaseDir & "/nimbase.h")):
  nimbaseDir = parentDir(parentDir(parentDir(parentDir(system.findExe("gcc"))))) & "/lib"
if (not system.fileExists(nimbaseDir & "/nimbase.h")):
  nimbaseDir = parentDir(nimbleDir) & "/.choosenim/toolchains/nim-" & system.NimVersion & "/lib"
cpFile(nimbaseDir / "nimbase.h", thisDir() / "../cpp" / "nimbase.h")
  
proc execCmd(command: string) = 
  when defined(windows): 
    exec "cmd /c \"" & command & "\""
  else:
    exec command

proc buildC() = 
  ## creates python and C/C++ libraries
  
  let stdOptions = "--header:" & application & ".h --app:staticlib -d:just_core -d:noSignalHandler -d:danger -d:release -d:androidNDK -d:noMain --os:android --threads:on "
 
  rmDir("./../cpp/arm64-v8a")
  selfExec " cpp -c " & stdOptions & "--cpu:arm64 --nimcache:./../cpp/arm64-v8a " & mainApp
  rmDir("./../cpp/armeabi-v7a")
  selfExec " cpp -c " & stdOptions & " --cpu:arm --nimcache:./../cpp/armeabi-v7a " & mainApp
  rmDir("./../cpp/x86")
  selfExec " cpp -c " & stdOptions & " --cpu:i386 --nimcache:./../cpp/x86 " & mainApp
  rmDir("./../cpp/x86_64")
  selfExec " cpp -c " & stdOptions & " --cpu:amd64 --nimcache:./../cpp/x86_64 " & mainApp
  let oldDir = thisDir() 
  cd uiDir
  execCmd("npm install")
  cd oldDir
  execCmd("npm run build --prefix " & uiDir)
  # cpFile("../../nimview/src/backend-helper.js", uiDir & "/dist/backend-helper.js")
  cpFile("../../nimview/src/backend-helper.js", uiDir & "/public/backend-helper.js")
  cpDir(uiDir & "/public", "../assets")

task nimToC, "Build Libs":
  buildC()

task serve, "Serve NPM":
  execCmd("npm run serve --prefix " & uiDir)
