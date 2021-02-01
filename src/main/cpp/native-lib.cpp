#include <jni.h>
#include <string>
#include <string.h>
extern "C" {
#include "nim_jni_callback.h"
}


extern "C" JNIEXPORT jstring JNICALL
Java_com_example_androidjni_NativeCpp_call(
        JNIEnv* env,
        jobject /* this */, jstring command) {
    jboolean iscopy;
    // std::string hello = "Hello from C++: " + std::string((*env).GetStringUTFChars(command, &iscopy));
    std::string test = "null";
    NimMain();
    const char* ret = nimHelloWorld("success2");
    if (ret) {
        test = std::string(ret);
    }
    std::string hello = "Hello from nim: " + test;
    return env->NewStringUTF(hello.c_str());
}
