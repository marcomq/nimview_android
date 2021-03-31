# Nimview UI Library 
# Copyright (C) 2021, by Marco Mengelkoch
# Licensed under MIT License, see License file for more details
# git clone https://github.com/marcomq/nimview

import os, system, tables
import json, logging

# run "nimble release" or "nimble debug" to compile

when not defined(just_core):
  const compileWithWebview = defined(useWebview) or not defined(useServer)
  import strutils, uri
  import nimpy
  import jester
  import globalToken
  # import browsers
  when compileWithWebview:
    import webview except debug
    var myWebView: Webview
  var responseHttpHeader {.threadVar.}: seq[tuple[key, val: string]] # will be set when starting Jester
else:
  const compileWithWebview = false
  # Just core features. Disable jester, webview nimpy and exportpy
  macro exportpy(def: untyped): untyped =
    result = def

type ReqUnknownException* = object of CatchableError
type ReqDeniedException* = object of CatchableError

var reqMap {.threadVar.}: Table[string, proc(value: string): string {.gcsafe.}] 
var requestLogger {.threadVar.}: FileLogger
var useServer* = not compileWithWebview or 
  (defined(useServer) or defined(debug) or (os.fileExists("/.dockerenv")))
var useGlobalToken* = true

proc setUseServer*(val: bool) {.exportpy.} =
  useServer = val

proc setUseGlobalToken*(val: bool) {.exportpy.} =
  useGlobalToken = val

logging.addHandler(newConsoleLogger())

proc enableRequestLogger*() {.exportpy.} =
  ## Start to log all requests with content, even passwords, into file "requests.log".
  ## The file can be used for automated tests, to archive and replay all actions.
  if nimview.requestLogger.isNil:
    debug "creating request logger, further requests will be logged to file and flushed at application end"
    if not os.fileExists("requests.log"):
      var createFile = system.open("requests.log", system.fmWrite)
      createFile.close()
    var requestLoggerTmp = newFileLogger("requests.log", fmtStr = "")

    nimview.requestLogger.swap(requestLoggerTmp)
  nimview.requestLogger.levelThreshold = logging.lvlAll

proc disableRequestLogger*() {.exportpy.} =
  ## Will stop to log to "requests.log" (default)
  if not requestLogger.isNil:
    requestLogger.levelThreshold = logging.lvlNone

proc addRequest*(request: string, callback: proc(value: string): string {.gcsafe.}) {.exportpy.} =
  ## This will register a function "callback" that can run on back-end.
  ## "addRequest" will be performed with "value" each time the javascript client calls:
  ## `window.ui.backend(request, value, function(response) {...})`
  ## with the specific "request" value.
  ## There is a wrapper for python, C and C++ to handle strings in each specific programming language
  nimview.reqMap[request] = callback

proc dispatchRequest*(request: string, value: string): string {.exportpy.} =
  ## Global string dispatcher that will trigger a previously registered functions
  nimview.reqMap.withValue(request, callbackFunc) do: # if request available, run request callback
    result = callbackFunc[](value)
  do:
    raise newException(ReqUnknownException, "404 - Request unknown")

proc dispatchJsonRequest*(jsonMessage: JsonNode): string =
  ## Global json dispatcher that will be called from webview AND jester
  ## This will extract specific values that were prepared by backend-helper.js
  ## and forward those values to the string dispatcher.
  let request = $jsonMessage["request"].getStr()
  if request == "getGlobalToken":
    return
  var value = $jsonMessage["value"].getStr()
  if (value == ""):
    value = $jsonMessage["value"]
  if not requestLogger.isNil:
    requestLogger.log(logging.lvlInfo, $jsonMessage)
  result = dispatchRequest(request, value)

proc dispatchCommandLineArg*(escapedArgv: string): string  {.exportpy.} =
  ## Will handle previously logged request json and forward those to registered functions.
  try:
    let jsonMessage = parseJson(escapedArgv)
    result = dispatchJsonRequest(jsonMessage)
  except ReqUnknownException:
    warn "Request is unknown in " & escapedArgv
  except:
    warn "Couldn't parse specific line arg: " & escapedArgv

proc readAndParseJsonCmdFile*(filename: string) {.exportpy.} =
  ## Will open, parse a file of previously logged requests and re-runs those requests.
  if (os.fileExists(filename)):
    debug "opening file for parsing: " & filename
    let file = system.open(filename, system.FileMode.fmRead)
    var line: TaintedString
    while (file.readLine(line)):
      # TODO: escape line if source file cannot be trusted
      let retVal = nimview.dispatchCommandLineArg(line.string)
      debug retVal
    close(file)
  else:
    logging.error "File does not exist: " & filename

when not defined(just_core):
  when defined release:
    const backendHelperJs = system.staticRead("backend-helper.js")
  else:
    const backendHelperJsStatic = system.staticRead("backend-helper.js")
    var backendHelperJs {.threadVar.}: string

  proc dispatchHttpRequest*(jsonMessage: JsonNode, headers: HttpHeaders): string =
    ## Modify this, if you want to add some authentication, input format validation
    ## or if you want to process HttpHeaders.
    if not nimview.useGlobalToken or globalToken.checkToken(headers):
        return dispatchJsonRequest(jsonMessage)
    else:
        let request = $jsonMessage["request"].getStr()
        if request != "getGlobalToken":
            raise newException(ReqDeniedException, "403 - Token expired")

  template respond(code: untyped, header: untyped, message: untyped): untyped =
    mixin resp
    jester.resp code, header, message

  proc handleRequest(request: Request): Future[ResponseData] {.async.} =
    ## used by HttpServer
    block route:
      var response: string
      var requestPath: string = request.pathInfo
      var resultId = 0
      case requestPath
      of "/backend-helper.js":
        var header = @{"Content-Type": "application/javascript"}
        header.add(nimview.responseHttpHeader)
        respond Http200, header, nimview.backendHelperJs
      else:
        try:
          let separatorFound = requestPath.rfind({'#', '?'})
          if separatorFound != -1:
            requestPath = requestPath[0 ..< separatorFound]
          if (requestPath == "/"):
            requestPath = "/index.html"

          var potentialFilename = request.getStaticDir() & "/" &
              requestPath.replace("..", "")
          if os.fileExists(potentialFilename):
            debug "Sending " & potentialFilename
            # jester.sendFile(potentialFilename)
            let fileData = splitFile(potentialFilename)
            let contentType = case fileData.ext:
              of ".json": "application/json;charset=utf-8"
              of ".js": "text/javascript;charset=utf-8"
              of ".css": "text/css;charset=utf-8"
              of ".jpg": "image/jpeg"
              of ".txt": "text/plain;charset=utf-8"
              of ".map": "application/octet-stream"
              else: "text/html;charset=utf-8"
            var header = @{"Content-Type": contentType}
            header.add(nimview.responseHttpHeader)
            respond Http200, header, system.readFile(potentialFilename)
          else:
            if (request.body == ""):
              raise newException(ReqUnknownException, "404 - File not found")

            # if not a file, assume this is a json request
            var jsonMessage: JsonNode
            debug request.body
            if unlikely(request.body == ""):
              jsonMessage = parseJson(uri.decodeUrl(requestPath))
            else:
              jsonMessage = parseJson(request.body)
            resultId = jsonMessage["responseId"].getInt()
            {.gcsafe.}:
              var currentToken = globalToken.byteToString(globalToken.getFreshToken())
              response = dispatchHttpRequest(jsonMessage, request.headers)
              let jsonResponse = %* { ($jsonMessage["key"]).unescape(): response}
              var header = @{"Global-Token": currentToken}
              respond Http200, header, $jsonResponse

        except ReqUnknownException:
          respond Http404, nimview.responseHttpHeader, $ %* {"error": "404",
              "value": getCurrentExceptionMsg(), "resultId": resultId}

        except ReqDeniedException:
          respond Http403, nimview.responseHttpHeader, $ %* {"error": "403",
              "value": getCurrentExceptionMsg(), "resultId": resultId}
        except:
          respond Http500, nimview.responseHttpHeader, $ %* {"error": "500",
              "value": "request doesn't contain valid json",
              "resultId": resultId}
        
  proc getCurrentAppDir(): string =
      let applicationName = os.getAppFilename().extractFilename()
      debug applicationName
      if (applicationName.startsWith("python") or applicationName.startsWith("platform-python")):
        result = os.getCurrentDir()
      else:
        result = os.getAppDir()

  proc copyBackendHelper (indexHtml: string) =
    let folder = indexHtml.parentDir()
    let targetJs = folder / "backend-helper.js"
    try:
      if not os.fileExists(targetJs) and indexHtml.endsWith(".html"):
        # read index html file and check if it actually requires backend helper
        let indexHtmlContent = system.readFile(indexHtml)
        if indexHtmlContent.contains("backend-helper.js"):
          let sourceJs = nimview.getCurrentAppDir() / "../src/backend-helper.js"
          if (not os.fileExists(sourceJs) or ((system.hostOS == "windows") and defined(debug))):
            debug "writing to " & targetJs
            if nimview.backendHelperJs != "":
              system.writeFile(targetJs, nimview.backendHelperJs)
          elif (os.fileExists(sourceJs)):
              debug "symlinking to " & targetJs
              os.createSymlink(sourceJs, targetJs)
    except:
      logging.error "backend-helper.js not copied"

  proc getAbsPath(indexHtmlFile: string): (string, string) =
    let separatorFound = indexHtmlFile.rfind({'#', '?'})
    if separatorFound == -1:
      result[0] = indexHtmlFile
    else:
      result[0] = indexHtmlFile[0 ..< separatorFound]
      result[1] = indexHtmlFile[separatorFound .. ^1]
    if (not os.isAbsolute(result[0])):
      result[0] = nimview.getCurrentAppDir() / indexHtmlFile

  proc checkFileExists(filePath: string, message: string) =
    if not os.fileExists(filePath):
      raise newException(IOError, message)

  proc startHttpServer*(indexHtmlFile: string, port: int = 8000,
      bindAddr: string = "localhost") {.exportpy.} =
    ## Start Http server (Jester) in blocking mode. indexHtmlFile will displayed for "/".
    ## Files in parent folder or sub folders may be accessed without further check. Will run forever.
    var (indexHtmlPath, parameter) = nimview.getAbsPath(indexHtmlFile)
    discard parameter # needs to be inserted into url manually
    nimview.checkFileExists(indexHtmlPath, "Required file index.html not found at " & indexHtmlPath & 
      "; cannot start UI; the UI folder needs to be relative to the binary")
    when not defined release:
      nimview.backendHelperJs = nimview.backendHelperJsStatic
      try:
        nimview.backendHelperJs = system.readFile(nimview.getCurrentAppDir() / "../src/backend-helper.js")
      except: 
        discard
    nimview.copyBackendHelper(indexHtmlPath)
    var origin = "http://" & bindAddr
    if (bindAddr == "0.0.0.0"):
      origin = "*"
    nimview.responseHttpHeader = @{"Access-Control-Allow-Origin": origin}
    let settings = jester.newSettings(
        port = Port(port),
        bindAddr = bindAddr,
        staticDir = indexHtmlPath.parentDir())
    var myJester = jester.initJester(nimview.handleRequest, settings = settings)
    # debug "open default browser"
    # browsers.openDefaultBrowser("http://" & bindAddr & ":" & $port / parameter)
    myJester.serve()

  proc stopDesktop*() {.exportpy.} =
    ## Will stop the Http server - may trigger application exit.
    when compileWithWebview:
      debug "stopping ..."
      if not myWebView.isNil():
        myWebView.terminate()

  proc startDesktop*(indexHtmlFile: string, title: string = "nimview",
      width: int = 640, height: int = 480, resizable: bool = true,
          debug: bool = defined release) {.exportpy.} =
    ## Will start Webview Desktop UI to display the index.hmtl file in blocking mode.
    when compileWithWebview:
      var (indexHtmlPath, parameter) = nimview.getAbsPath(indexHtmlFile)
      nimview.checkFileExists(indexHtmlPath, "Required file index.html not found at " & indexHtmlPath & 
        "; cannot start UI; the UI folder needs to be relative to the binary")
      nimview.copyBackendHelper(indexHtmlPath)
      # var fullScreen = true
      myWebView = webview.newWebView(title, "file://" / indexHtmlPath & parameter, width,
          height, resizable = resizable, debug = debug)
      myWebView.bindProc("backend", "alert", proc (message: string) =
        {.gcsafe.}:
          myWebView.info("alert", message))
      myWebView.bindProc("backend", "call", proc (message: string) =
        info message
        let jsonMessage = json.parseJson(message)
        let resonseId = jsonMessage["responseId"].getInt()
        let response = dispatchJsonRequest(jsonMessage)
        let evalJsCode = "window.ui.applyResponse('" & 
            response.replace("\\", "\\\\").replace("\'", "\\'") &
            "'," & $resonseId & ");"
        {.gcsafe.}:
          let responseCode = myWebView.eval(evalJsCode)
          discard responseCode
      )
#[    proc changeColor() = myWebView.setColor(210,210,210,100)
      proc toggleFullScreen() = fullScreen = not myWebView.setFullscreen(fullScreen) ]#
      myWebView.run()
      myWebView.exit()
      dealloc(myWebView)

  proc start*(indexHtmlFile: string, port: int = 8000, bindAddr: string = "localhost", title: string = "nimview",
        width: int = 640, height: int = 480, resizable: bool = true) {.exportpy.} =
    ## Tries to automatically select the Http server in debug mode or when no UI available
    ## and the Webview Desktop App in Release mode, if UI available.
    ## The debug mode information will not be available for python or dll.
    let displayAvailable = 
      when (system.hostOS == "windows"): true 
      else: ( os.getEnv("DISPLAY") != "")
    if useServer or not displayAvailable:
      startHttpServer(indexHtmlFile, port, bindAddr)
    else:
      startDesktop(indexHtmlFile, title, width, height, resizable)

proc main() =
  when not defined(noMain):
    debug "starting nim main"
    when system.appType != "lib" and not defined(just_core):
      nimview.addRequest("appendSomething", proc (value: string): string =
        result = "'" & value & "' modified by Nim Backend")

      let argv = os.commandLineParams()
      for arg in argv:
        nimview.readAndParseJsonCmdFile(arg)
      # let indexHtmlFile = "../examples/vue/dist/index.html"
      let indexHtmlFile = "../examples/svelte/public/index.html"
      nimview.enableRequestLogger()
      # nimview.startDesktop(indexHtmlFile)
      # nimview.startHttpServer(indexHtmlFile)
      nimview.startHttpServer(indexHtmlFile)

when isMainModule:
  main()
