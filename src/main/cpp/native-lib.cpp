#include <jni.h>
#include <string>
#include <string.h>
#include "custom_nimview.h"


thread_local bool nimInitialized = false;

#define THIS_PROJECT_PREFIX Java_com_example_androidjni
extern "C" JNIEXPORT jstring JNICALL
Java_com_example_androidjni_NativeCpp_callNim(
        JNIEnv* env,
        jobject /* this */, jstring request, jstring value) {
    char* cRequest = const_cast<char*>(env->GetStringUTFChars(request, nullptr));
    char* cValue = const_cast<char*>(env->GetStringUTFChars(value, nullptr));
    if (!nimInitialized) {
        NimMain();
        nimInitialized = true;
    }
    std::string result(nimview_dispatchRequest(cRequest, cValue));
    env->ReleaseStringUTFChars(request, cRequest);
    env->ReleaseStringUTFChars(value, cValue);
    return env->NewStringUTF(result.c_str());
}
