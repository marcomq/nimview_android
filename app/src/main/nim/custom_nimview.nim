import ../../nimview/src/nimview
import ../../nimview/src/nimview_c

when not defined(just_core):
    import os
# type StdString* {.importcpp: "std::string", header: "string".} = object
    
nimview.addRequest("appendSomething", proc (value: string): string =  # nimview.addRequest
    result = "'" & value & "' modified by Nim Backend")

proc developStart() =
    when not defined(just_core):
        let argv = os.commandLineParams()
        for arg in argv:
            nimview.readAndParseJsonCmdFile(arg)
        echo "starting nim"
        nimview.start("../../nimview/examples/svelte/public/index.html")
    else:
        echo "cannot start with -d:just_core"

when isMainModule:
  developStart()