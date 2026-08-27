# -*- coding: utf-8 -*-
"""Flask 本地服务：前端静态资源 + 内容/作业/设置/PDF/PyCharm/DeepSeek 接口。"""
import os
import sys

from flask import Flask, jsonify, request, send_file, send_from_directory
from src import deepseek, pycharm_launcher, settings, storage
from content import content_data

PORT = 8742

# 因为 content_data 在 content/ 目录，确保可导入
ROOT = settings.ROOT
if os.path.isdir(os.path.join(ROOT, "content")):
    sys.path.insert(0, ROOT)

app = Flask(__name__, static_folder=os.path.join(ROOT, "web"), static_url_path="/static")


def _find_chapter(cid):
    for c in content_data.CHAPTERS:
        if c["id"] == cid:
            return c
    return None


def _find_project(pid):
    for p in content_data.PROJECTS:
        if p["id"] == pid:
            return p
    return None


@app.route("/")
def index():
    return send_from_directory(os.path.join(ROOT, "web"), "index.html")


@app.route("/api/chapters")
def api_chapters():
    return jsonify(
        [
            {
                "id": c["id"],
                "title": c["title"],
                "book_chapter": c["book_chapter"],
                "summary": c["summary"],
            }
            for c in content_data.CHAPTERS
        ]
    )


@app.route("/api/chapter/<cid>")
def api_chapter(cid):
    c = _find_chapter(cid)
    if not c:
        return jsonify({"error": "not found"}), 404
    return jsonify(c)


@app.route("/api/projects")
def api_projects():
    return jsonify(
        [
            {
                "id": p["id"],
                "title": p["title"],
                "book_chapter": p["book_chapter"],
                "summary": p["summary"],
                "tech": p.get("tech", ""),
                "setup": p.get("setup", ""),
            }
            for p in content_data.PROJECTS
        ]
    )


@app.route("/api/project/<pid>")
def api_project(pid):
    p = _find_project(pid)
    if not p:
        return jsonify({"error": "not found"}), 404
    return jsonify(p)


@app.route("/api/choose_file", methods=["POST"])
def api_choose_file():
    kind = (request.get_json(silent=True) or {}).get("kind", "")
    exts = (("PDF files", "*.pdf"),) if kind == "pdf" else (("exe files", "*.exe"), ("All files", "*.*"))
    try:
        import tkinter as tk
        from tkinter import filedialog

        root = tk.Tk()
        root.withdraw()
        path = filedialog.askopenfilename(filetypes=exts)
        root.destroy()
        return jsonify({"path": path})
    except Exception as e:
        return jsonify({"path": "", "error": str(e)})


@app.route("/api/settings", methods=["GET", "POST"])
def api_settings():
    if request.method == "POST":
        data = request.get_json(silent=True) or {}
        s = settings.load_settings()
        if "pdf_path" in data:
            s["pdf_path"] = data["pdf_path"]
        if "pycharm_path" in data:
            s["pycharm_path"] = data["pycharm_path"]
        settings.save_settings(s)
        return jsonify(s)
    return jsonify(settings.load_settings())


@app.route("/api/submissions", methods=["GET", "POST"])
def api_submissions():
    if request.method == "POST":
        data = request.get_json(silent=True) or {}
        rec = {
            "exercise_id": data.get("exercise_id", ""),
            "title": data.get("title", ""),
            "code": data.get("code", ""),
            "time": __import__("datetime").datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        subs = storage.add_submission(rec)
        return jsonify(subs)
    return jsonify(storage.load_submissions())


@app.route("/api/open_deepseek", methods=["POST"])
def api_open_deepseek():
    data = request.get_json(silent=True) or {}
    title = data.get("title", "练习")
    prompt_text = data.get("prompt", "")
    code = data.get("code", "")
    if not code.strip():
        return jsonify({"ok": False, "msg": "还没有可批改的代码，请先写代码。"})
    full = deepseek.build_grading_prompt(title, prompt_text, code)
    copied, opened = deepseek.open_deepseek(full)
    return jsonify(
        {
            "ok": True,
            "copied": copied,
            "opened": opened,
            "msg": ("已复制批改提示词到剪贴板，并打开 DeepSeek 网页，请粘贴后发送。"
                    if copied and opened
                    else "已尽力打开 DeepSeek；若未复制成功，请手动复制下方提示词。"),
        }
    )


def _python_cmd():
    """用于执行学生代码的解释器命令前缀。"""
    if not getattr(sys, "frozen", False):
        return [sys.executable]
    # 打包版里 sys.executable 是应用自身，必须从 PATH 找真正的 Python
    import shutil

    for name, extra in (("python.exe", []), ("python3.exe", []), ("py.exe", ["-3"])):
        p = shutil.which(name)
        if p:
            return [p] + extra
    return None


@app.route("/api/run", methods=["POST"])
def api_run():
    import subprocess

    data = request.get_json(silent=True) or {}
    code = data.get("code", "")
    if not code.strip():
        return jsonify({"ok": False, "msg": "没有可运行的代码。"})
    cmd = _python_cmd()
    if cmd is None:
        return jsonify(
            {"ok": False, "msg": "打包版需要在 PATH 中安装 Python 才能运行代码。请安装 Python，或在开发模式下用 python main.py 启动。"}
        )
    ws = os.path.join(settings.DATA_DIR, "workspace")
    os.makedirs(ws, exist_ok=True)
    tmp = os.path.join(ws, "_run_tmp.py")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(code)
    try:
        proc = subprocess.run(
            cmd + [tmp],
            capture_output=True,
            text=True,
            timeout=10,
            input="",
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        return jsonify({"ok": True, "output": out, "returncode": proc.returncode})
    except subprocess.TimeoutExpired:
        return jsonify({"ok": False, "msg": "运行超时（10 秒）。可能含有 input() 在等待输入，或陷入死循环。"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)})


@app.route("/api/pycharm/detect", methods=["GET"])
def api_pycharm_detect():
    return jsonify({"paths": pycharm_launcher.detect_pycharm()})


@app.route("/api/pycharm/open", methods=["POST"])
def api_pycharm_open():
    data = request.get_json(silent=True) or {}
    target = data.get("path", "")
    code = data.get("code")
    filename = data.get("filename")
    if code is not None and filename:
        ws = os.path.join(settings.DATA_DIR, "workspace")
        os.makedirs(ws, exist_ok=True)
        safe = os.path.basename(filename)
        if not safe.endswith(".py"):
            safe += ".py"
        target = os.path.join(ws, safe)
        with open(target, "w", encoding="utf-8") as f:
            f.write(code)
    s = settings.load_settings()
    pycharm = data.get("pycharm_path") or s.get("pycharm_path", "")
    if not target:
        return jsonify({"ok": False, "msg": "没有可打开的文件。"})
    ok, msg = pycharm_launcher.open_in_pycharm(pycharm, target)
    return jsonify({"ok": ok, "msg": msg})


@app.route("/pdf")
def serve_pdf():
    s = settings.load_settings()
    path = s.get("pdf_path", "")
    if not path or not os.path.exists(path):
        return (
            "PDF 文件未找到，请在“设置”中指定《Python编程从入门到实践》PDF 的路径。",
            404,
        )
    return send_file(path, mimetype="application/pdf")


def run():
    app.run(host="127.0.0.1", port=PORT, threaded=True, use_reloader=False)


if __name__ == "__main__":
    run()
