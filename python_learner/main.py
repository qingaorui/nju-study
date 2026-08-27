# -*- coding: utf-8 -*-
"""入口：启动本地 Flask 服务，并用 PyWebView 打开原生窗口。打包后即为 exe。"""
import socket
import sys
import threading
import time

import webview

from src import server

PORT = server.PORT
URL = f"http://127.0.0.1:{PORT}/"


def _wait_server(host, port, timeout=15):
    """等待 Flask 真正可响应，避免窗口打开时服务还没起来。"""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=1):
                return True
        except OSError:
            time.sleep(0.2)
    return False


def main():
    t = threading.Thread(target=server.run, daemon=True)
    t.start()
    _wait_server("127.0.0.1", PORT)

    webview.create_window(
        "Python 学习助手 · 派派",
        URL,
        width=1180,
        height=780,
        min_size=(900, 600),
    )
    webview.start()


if __name__ == "__main__":
    main()
