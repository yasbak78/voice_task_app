# whisper.cpp Native Libraries

This directory contains compiled whisper.cpp shared libraries for each platform.

## Build Instructions

### Android (arm64-v8a)

```bash
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21 \
  -DCMAKE_BUILD_TYPE=Release
make -j4
cp libwhisper.so ../native/whisper/android/arm64-v8a/
```

### Linux (x86_64)

```bash
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j4
cp libwhisper.so ../native/whisper/linux/
```

## Directory Structure

```
native/whisper/
├── android/
│   ├── arm64-v8a/
│   │   └── libwhisper.so
│   └── armeabi-v7a/
│       └── libwhisper.so
├── linux/
│   └── libwhisper.so
└── README.md
```

## Model Files

Download quantized models to `assets/models/`:
- `ggml-tiny.en-q5_1.bin` (~39MB) — default for MVP
- `ggml-small.en-q5_0.bin` (~488MB) — higher accuracy

URLs: `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/<filename>`
