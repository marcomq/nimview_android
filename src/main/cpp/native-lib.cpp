#include <jni.h>
#include <string>
#include <string.h>
extern "C" {
#include "custom_nimview.h"
}


extern "C" JNIEXPORT jstring JNICALL
Java_com_example_androidjni_NativeCpp_callNim(
        JNIEnv* env,
        jobject /* this */, jstring request, jstring value) {
    jboolean iscopy;
    // std::string hello = "Hello from C++: " + std::string((*env).GetStringUTFChars(command, &iscopy));
    NimMain();
    // const char* ret = nimHelloWorld("success 4");
    char* cRequest = const_cast<char*>(env->GetStringUTFChars(request, nullptr));
    char* cValue = const_cast<char*>(env->GetStringUTFChars(value, nullptr));
    std::string result(nimview_dispatchRequest(cRequest, cValue));
    env->ReleaseStringUTFChars(request, cRequest);
    env->ReleaseStringUTFChars(value, cValue);
    return env->NewStringUTF(result.c_str());
}
