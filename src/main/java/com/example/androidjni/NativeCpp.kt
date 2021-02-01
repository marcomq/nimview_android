package com.example.androidjni

object  NativeCpp {

    /**
     * A native method that is implemented by the 'native-lib' native library,
     * which is packaged with this application.
     */
    @SuppressWarnings("unused")
    @android.webkit.JavascriptInterface
    external fun call(command: String): String

    @SuppressWarnings("unused")
    @android.webkit.JavascriptInterface
    fun run2(): String  {
        return "Hello World :)))"
    }

}
