import ../../nimview/src/nimview_c
# type StdString* {.importcpp: "std::string", header: "string".} = object
    
addRequest("appendSomething", proc (value: string): string =  # nimview.addRequest
    result = "'" & value & "' modified by Nim Backend")
    
proc nimHelloWorld*(input: cstring): cstring {. cdecl, exportc, dynlib .} =
    let ret = " Hello nim World: " & $input
    return ret
