package com.example.androidjni

import android.net.Uri
import android.os.Bundle
import android.webkit.JsResult
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity


class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        webView = findViewById(R.id.webview)
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                if(Uri.parse(url).getHost().isNullOrEmpty()) {
                    return false;
                }
                view?.loadUrl(url)
                return true
            }
        }
        val settings = webView.getSettings()
        settings.setJavaScriptEnabled(true)
        settings.setDomStorageEnabled(true)
        webView.addJavascriptInterface(NativeCpp, "backend")
        webView.webChromeClient = object : WebChromeClient() {
            //Other methods for your WebChromeClient here, if needed..
            override fun onJsAlert(
                view: WebView,
                url: String,
                message: String,
                result: JsResult
            ): Boolean {
                return super.onJsAlert(view, url, message, result)
            }
        }
        webView.loadUrl("file:///android_asset/index.html")

    }


    companion object {
        // Used to load the 'native-lib' library on application startup.
        init {
            System.loadLibrary("native-lib")
        }
    }
}
