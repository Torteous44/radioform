#include <CoreAudio/AudioServerPlugIn.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

int main() {
    CFUUIDRef typeUUID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, kAudioServerPlugInTypeUUID);
    CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, typeUUID);

    char buffer[256];
    CFStringGetCString(uuidString, buffer, sizeof(buffer), kCFStringEncodingUTF8);

    printf("kAudioServerPlugInTypeUUID = %s\n", buffer);

    CFRelease(uuidString);
    CFRelease(typeUUID);

    return 0;
}
