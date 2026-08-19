package com.yuyu.dev.shizuku;

import com.yuyu.dev.shizuku.IUnzipCallback;

interface IUnzipService {
    void unzip(String source, String target, IUnzipCallback callback);
    boolean deleteFolder(String path);
    String[] sha256Files(in String[] paths);
    void destroy();
}
