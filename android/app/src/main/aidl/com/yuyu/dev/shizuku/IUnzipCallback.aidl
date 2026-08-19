package com.yuyu.dev.shizuku;

interface IUnzipCallback {
    void onProgress(int progress, String currentFile);
    void onComplete();
    void onError(String message);
}
