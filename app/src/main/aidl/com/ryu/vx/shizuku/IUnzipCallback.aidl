package com.ryu.vx.shizuku;

interface IUnzipCallback {
    void onProgress(int progress, String currentFile);
    void onComplete();
    void onError(String message);
}
