#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
智能题目解答助手 (QuestionSolver)
==============================
工作流程：
    1) 屏幕捕捉  —— 全屏半透明遮罩 + 鼠标拖拽框选题目区域
    2) 题目识别  —— 将截图直接发送给豆包视觉大模型（原生支持中文/英文/数学公式/图表）
    3) 豆包解答  —— 火山方舟 (Volcengine Ark) OpenAI 兼容接口返回答案、思路与步骤
    4) 结果展示  —— 清晰文本界面呈现，支持一键复制

说明：
    - 成品为单文件 EXE（PyInstaller --onefile 打包），运行时不依赖任何外部软件/插件。
    - 仅需联网 + 一个火山方舟 API Key（在设置中填写一次即可）。
"""

import os
import sys
import json
import base64
import io
import threading

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox, filedialog

import requests
from PIL import ImageGrab

# ----------------------------- DPI 适配（Windows） -----------------------------
try:
    import ctypes
    if hasattr(ctypes.windll, "shcore"):
        # PROCESS_PER_MONITOR_DPI_AWARE = 2
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:
    pass


APP_NAME = "智能题目解答助手"
# 配置文件与 EXE 同目录，避免写入系统目录
CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(sys.executable)), "config.json")

DEFAULT_PROMPT = (
    "你是一名专业的解题与讲解助手。请识别图片中的题目"
    "（支持中文、英文、数学公式、流程图/图表等多种题型），"
    "按以下结构用中文回答：\n\n"
    "【最终答案】\n（直接、准确地给出答案）\n\n"
    "【解题思路】\n（简要说明所用方法与思考方向）\n\n"
    "【详细步骤】\n（分步推导；数学公式可用 LaTeX 行内公式 $...$ 表示，"
    "图表类题目请描述读图结论并据此计算）\n"
)

DEFAULT_CONFIG = {
    "api_key": "",
    "model": "doubao-seed-2-0-lite-260215",
    "base_url": "https://ark.cn-beijing.volces.com/api/v3",
    "prompt": DEFAULT_PROMPT,
}


# ----------------------------- 配置读写 -----------------------------
def load_config():
    cfg = dict(DEFAULT_CONFIG)
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                cfg.update(json.load(f))
    except Exception:
        pass
    if not cfg.get("prompt"):
        cfg["prompt"] = DEFAULT_PROMPT
    return cfg


def save_config(cfg):
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)


# ----------------------------- 屏幕区域捕捉 -----------------------------
def capture_screen_region(master):
    """弹出全屏遮罩（以桌面快照为背景），用户拖拽框选题目区域，返回 PIL.Image；取消返回 None。

    关键修复：不再新建第二个 Tk()/嵌套 mainloop（tkinter 不支持，会导致遮罩不出现），
    改为复用主窗口派生 Toplevel + wait_window 模态，并以快照背景避免透明窗口点击穿透问题。
    """
    import ctypes
    try:
        from PIL import ImageTk
        _HAS_IMAGETK = True
    except Exception:
        _HAS_IMAGETK = False

    user32 = ctypes.windll.user32
    vx = user32.GetSystemMetrics(76)  # SM_XVIRTUALSCREEN
    vy = user32.GetSystemMetrics(77)  # SM_YVIRTUALSCREEN
    vw = user32.GetSystemMetrics(78)  # SM_CXVIRTUALSCREEN
    vh = user32.GetSystemMetrics(79)  # SM_CYVIRTUALSCREEN

    # 先抓取整屏快照作为遮罩背景（保证像素对齐且窗口可点击）
    try:
        full = ImageGrab.grab(all_screens=True)
    except Exception:
        full = ImageGrab.grab()

    overlay = tk.Toplevel(master)
    overlay.overrideredirect(True)
    overlay.attributes("-topmost", True)
    overlay.geometry(f"{vw}x{vh}+{vx}+{vy}")

    canvas = tk.Canvas(overlay, cursor="cross", highlightthickness=0, bg="black")
    canvas.pack(fill="both", expand=True)

    if _HAS_IMAGETK:
        try:
            bg = ImageTk.PhotoImage(full)
            canvas.image = bg  # 保持引用，避免被 GC
            canvas.create_image(0, 0, image=bg, anchor="nw")
        except Exception:
            pass

    canvas.create_text(
        vw // 2, 28, text="按住鼠标拖拽框选题目区域 · Esc / 右键 取消",
        fill="#ff4d4f", font=("Microsoft YaHei", 13),
    )

    state = {"rect": None, "dims": [], "sx": 0, "sy": 0, "sel": None}

    def draw_dims(x1, y1, x2, y2):
        for d in state["dims"]:
            canvas.delete(d)
        state["dims"] = []
        if x2 - x1 < 1 or y2 - y1 < 1:
            return
        # 选区外变暗（stipple 半透明效果），让选区更醒目
        for (dx, dy, dw, dh) in [
            (0, 0, x1, vh),
            (x2, 0, vw - x2, vh),
            (x1, 0, x2 - x1, y1),
            (x1, y2, x2 - x1, vh - y2),
        ]:
            if dw > 0 and dh > 0:
                r = canvas.create_rectangle(
                    dx, dy, dx + dw, dy + dh,
                    fill="black", stipple="gray50", outline="",
                )
                state["dims"].append(r)

    def on_down(e):
        state["sx"], state["sy"] = e.x_root, e.y_root
        if state["rect"]:
            canvas.delete(state["rect"])
        state["rect"] = canvas.create_rectangle(
            e.x_root - vx, e.y_root - vy, e.x_root - vx, e.y_root - vy,
            outline="#ff4d4f", width=3,
        )
        draw_dims(e.x_root - vx, e.y_root - vy, e.x_root - vx, e.y_root - vy)

    def on_move(e):
        if state["rect"] is None:
            return
        x1, y1, x2, y2 = state["sx"], state["sy"], e.x_root, e.y_root
        canvas.coords(state["rect"], x1 - vx, y1 - vy, x2 - vx, y2 - vy)
        draw_dims(min(x1, x2) - vx, min(y1, y2) - vy,
                  max(x1, x2) - vx, max(y1, y2) - vy)

    def finish(e):
        ex, ey = e.x_root, e.y_root
        x1, y1 = min(state["sx"], ex), min(state["sy"], ey)
        x2, y2 = max(state["sx"], ex), max(state["sy"], ey)
        if x2 - x1 >= 5 and y2 - y1 >= 5:
            state["sel"] = (x1, y1, x2, y2)
        overlay.destroy()

    def cancel(e=None):
        state["sel"] = None
        overlay.destroy()

    canvas.bind("<ButtonPress-1>", on_down)
    canvas.bind("<B1-Motion>", on_move)
    canvas.bind("<ButtonRelease-1>", finish)
    canvas.bind("<ButtonPress-3>", cancel)
    overlay.bind("<Escape>", cancel)
    overlay.bind("<ButtonPress-3>", cancel)

    overlay.grab_set()

    # 最小化主窗口，避免主窗口自身进入截图；无论成功或取消都恢复
    master.iconify()
    try:
        master.wait_window(overlay)
    finally:
        master.deiconify()
        master.lift()

    if not state["sel"]:
        return None
    x1, y1, x2, y2 = state["sel"]
    return full.crop((x1 - vx, y1 - vy, x2 - vx, y2 - vy))


# ----------------------------- 调用豆包视觉接口 -----------------------------
def call_doubao(cfg, image):
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")

    url = cfg["base_url"].rstrip("/") + "/chat/completions"
    headers = {
        "Authorization": "Bearer " + cfg["api_key"],
        "Content-Type": "application/json",
    }
    payload = {
        "model": cfg["model"],
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": cfg.get("prompt") or DEFAULT_PROMPT},
                    {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64}},
                ],
            }
        ],
    }

    resp = requests.post(url, headers=headers, json=payload, timeout=180)
    if resp.status_code != 200:
        raise RuntimeError(f"API 返回错误 {resp.status_code}：{resp.text[:600]}")
    data = resp.json()
    return data["choices"][0]["message"]["content"]


# ----------------------------- 主界面 -----------------------------
class App:
    def __init__(self, root):
        self.root = root
        self.last_image = None
        root.title(APP_NAME + "  v1.0")
        root.geometry("860x640")
        try:
            root.iconbitmap()
        except Exception:
            pass
        self._build_ui()
        self.set_status("就绪。点击「截图解题」开始。")

    def _build_ui(self):
        # 顶部按钮栏
        top = ttk.Frame(self.root)
        top.pack(fill="x", padx=10, pady=8)

        self.btn_solve = ttk.Button(top, text="📷 截图解题", command=self.on_capture)
        self.btn_solve.pack(side="left", padx=(0, 6))

        ttk.Button(top, text="🔁 重新求解上一张", command=self.on_resolve).pack(side="left", padx=6)
        ttk.Button(top, text="⚙ 设置", command=self.open_settings).pack(side="left", padx=6)
        ttk.Button(top, text="📋 复制答案", command=self.copy_answer).pack(side="left", padx=6)
        ttk.Button(top, text="🗑 清空", command=self.clear).pack(side="left", padx=6)
        ttk.Button(top, text="💾 保存", command=self.save_answer).pack(side="left", padx=6)

        # 结果展示区
        mid = ttk.Frame(self.root)
        mid.pack(fill="both", expand=True, padx=10, pady=(0, 6))

        self.text = scrolledtext.ScrolledText(
            mid, wrap="word", font=("Microsoft YaHei", 11), padx=10, pady=10,
        )
        self.text.pack(fill="both", expand=True)
        self.text.insert(
            "1.0",
            "使用步骤：\n"
            "1. 点击「截图解题」，用鼠标拖拽框选屏幕上的题目区域；\n"
            "2. 软件自动将截图发送给豆包视觉大模型进行识别与解答；\n"
            "3. 解答结果会显示在此处，点击「复制答案」即可复制到剪贴板。\n\n"
            "提示：首次使用请先点击「设置」填写火山方舟 API Key。",
        )
        self.text.configure(state="disabled")

        # 状态栏
        self.status = ttk.Label(self.root, text="", foreground="#555", anchor="w")
        self.status.pack(fill="x", padx=10, pady=(0, 8))

    def set_status(self, msg):
        self.status.configure(text=msg)

    def on_capture(self):
        self.set_status("请框选题目区域…")
        self.root.update_idletasks()
        try:
            img = capture_screen_region(self.root)
        except Exception as e:
            self.set_status("截图失败。")
            messagebox.showerror("截图失败", str(e))
            return
        if img is None:
            self.set_status("已取消截图。")
            return
        self.last_image = img
        self.solve(img)

    def on_resolve(self):
        if self.last_image is None:
            messagebox.showinfo("提示", "还没有可求解的截图，请先「截图解题」。")
            return
        self.solve(self.last_image)

    def solve(self, image):
        cfg = load_config()
        if not cfg.get("api_key"):
            messagebox.showwarning("缺少 API Key", "请先点击「设置」填写火山方舟 API Key。")
            self.open_settings()
            return
        self.set_status("正在识别并求解，请稍候…（可能需要十几秒）")
        self.btn_solve.configure(state="disabled")

        def worker():
            try:
                answer = call_doubao(cfg, image)
                self.root.after(0, self.show_answer, answer)
            except Exception as e:
                self.root.after(0, self.show_error, str(e))
            finally:
                self.root.after(0, lambda: self.btn_solve.configure(state="normal"))

        threading.Thread(target=worker, daemon=True).start()

    def show_answer(self, text):
        self.text.configure(state="normal")
        self.text.delete("1.0", "end")
        self.text.insert("1.0", text)
        self.text.configure(state="disabled")
        self.set_status("解答完成。")

    def show_error(self, msg):
        self.set_status("出错了，详见弹窗。")
        messagebox.showerror("求解失败", msg)

    def copy_answer(self):
        content = self.text.get("1.0", "end").strip()
        if not content:
            return
        self.root.clipboard_clear()
        self.root.clipboard_append(content)
        self.set_status("答案已复制到剪贴板。")

    def clear(self):
        self.last_image = None
        self.text.configure(state="normal")
        self.text.delete("1.0", "end")
        self.text.configure(state="disabled")
        self.set_status("已清空。")

    def save_answer(self):
        content = self.text.get("1.0", "end").strip()
        if not content:
            return
        path = filedialog.asksaveasfilename(
            defaultextension=".txt", filetypes=[("文本文件", "*.txt")],
            title="保存解答为文本",
        )
        if path:
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            self.set_status(f"已保存：{path}")

    def open_settings(self):
        cfg = load_config()
        win = tk.Toplevel(self.root)
        win.title("设置")
        win.geometry("600x460")
        win.resizable(False, False)
        win.transient(self.root)
        win.grab_set()

        ttk.Label(win, text="火山方舟 API Key：").pack(anchor="w", padx=14, pady=(12, 0))
        key_var = tk.StringVar(value=cfg.get("api_key", ""))
        key_entry = ttk.Entry(win, textvariable=key_var, show="*", width=70)
        key_entry.pack(fill="x", padx=14, pady=(2, 6))

        show_var = tk.BooleanVar(value=False)

        def toggle():
            key_entry.configure(show="" if show_var.get() else "*")

        ttk.Checkbutton(win, text="显示密钥", variable=show_var, command=toggle).pack(anchor="w", padx=14)

        ttk.Label(win, text="模型 ID（视觉模型，可改）：").pack(anchor="w", padx=14, pady=(8, 0))
        model_var = tk.StringVar(value=cfg.get("model", DEFAULT_CONFIG["model"]))
        ttk.Entry(win, textvariable=model_var, width=70).pack(fill="x", padx=14, pady=(2, 6))

        ttk.Label(win, text="API Base URL：").pack(anchor="w", padx=14, pady=(8, 0))
        url_var = tk.StringVar(value=cfg.get("base_url", DEFAULT_CONFIG["base_url"]))
        ttk.Entry(win, textvariable=url_var, width=70).pack(fill="x", padx=14, pady=(2, 6))

        ttk.Label(win, text="解题提示词（可自定义）：").pack(anchor="w", padx=14, pady=(8, 0))
        prompt_box = scrolledtext.ScrolledText(win, height=7, font=("Microsoft YaHei", 10))
        prompt_box.pack(fill="x", padx=14, pady=(2, 6))
        prompt_box.insert("1.0", cfg.get("prompt", DEFAULT_PROMPT))

        def save():
            new_cfg = {
                "api_key": key_var.get().strip(),
                "model": model_var.get().strip() or DEFAULT_CONFIG["model"],
                "base_url": url_var.get().strip() or DEFAULT_CONFIG["base_url"],
                "prompt": prompt_box.get("1.0", "end").strip() or DEFAULT_PROMPT,
            }
            save_config(new_cfg)
            messagebox.showinfo("已保存", "设置已保存到程序目录下的 config.json。")
            win.destroy()

        ttk.Button(win, text="保存", command=save).pack(side="right", padx=14, pady=(0, 12))


def main():
    root = tk.Tk()
    App(root)
    root.mainloop()


if __name__ == "__main__":
    main()
