# This specific file is based on https://github.com/yglukhov/nimpy/blob/master/nimpy.nimble

version     = "0.1.0"
author      = "Marco Mengelkoch"
description = "Nim / C library to run webview with HTML/JS as UI"
license     = "MIT"

# Dependencies
# you may skip jester, nimpy and webview when compiling with nim c -d:just_core
# alternatively, you still can just skip webkit by compiling with -d:useServer

# Currently, Webview requires gcc and doesn't work with vcc or clang

requires "nim >= 0.17.0", "jester >= 0.5.0", "nimpy >= 0.1.1", "webview == 0.1.0"
const uiDir = "../../nimview/examples/svelte"
const application = "custom_nimview"
bin = @[application]
const mainApp = application & ".nim"
const libraryFile =  mainApp

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

proc buildCForArch(cpu, path: string) =
  rmDir(path)
  const stdOptions = "--header:" & application & ".h --app:staticlib -d:just_core -d:noSignalHandler -d:danger -d:release -d:androidNDK -d:noMain --os:android --threads:on "
  selfExec " cpp -c " & stdOptions & "--cpu:" & cpu & " --nimcache:" & path & " " & mainApp

proc buildC() = 
  ## creates python and C/C++ libraries
  buildCForArch("arm64", "./../cpp/arm64-v8a")
  buildCForArch("arm", "./../cpp/armeabi-v7a")
  buildCForArch("i386", "./../cpp/x86")
  buildCForArch("amd64", "./../cpp/x86_64")

proc buildJs() = 
  # let oldDir = thisDir() 
  # cd uiDir
  # execCmd("npm install")
  # cd oldDir
  execCmd("npm run build --prefix " & uiDir)
  # cpFile("../../nimview/src/backend-helper.js", uiDir & "/dist/backend-helper.js")
  rmDir("../assets")
  mkdir("../assets")
  cpDir(uiDir & "/public", "../assets")
  cpFile("../../nimview/src/backend-helper.js", uiDir & "/public/backend-helper.js")

task buildCAndJs, "Create C files and compile svelte JS files":
  buildC()
  buildJs()

task serve, "Serve NPM":
  execCmd("npm run serve --prefix " & uiDir)
