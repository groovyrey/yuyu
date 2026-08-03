package com.ryu.vx.shizuku;

import com.ryu.vx.shizuku.IUnzipCallback;

interface IUnzipService {
    void unzip(String source, String target, IUnzipCallback callback);
    boolean deleteFolder(String path);
    String[] sha256Files(in String[] paths);
    void destroy();
}
