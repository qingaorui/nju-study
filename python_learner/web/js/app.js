// Python 学习助手 · 派派 前端逻辑
"use strict";

const $ = (s) => document.querySelector(s);
const esc = (s) =>
  String(s == null ? "" : s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

let currentChapter = null;
let currentProject = null;
let currentExercise = null;
let currentSectionIndex = 0;

/* ---------- 视图切换 ---------- */
function switchView(name) {
  document.querySelectorAll(".view").forEach((v) => (v.hidden = true));
  const map = {
    home: "view-home",
    pdf: "view-pdf",
    homework: "view-homework",
    settings: "view-settings",
  };
  const id = map[name] || name; // chapter/section/exercise/project 直接传 id
  const el = document.getElementById(id);
  if (el) el.hidden = false;
  document.querySelectorAll(".nav-btn").forEach((b) =>
    b.classList.toggle("active", b.dataset.view === name)
  );
  if (name === "homework") loadHomework();
  if (name === "settings") loadSettings();
  if (name === "pdf") reloadPdf();
}

function reloadPdf() {
  const f = $("#pdf-frame");
  f.src = "/pdf?t=" + Date.now();
}

window.goHome = () => switchView("home");

/* ---------- Toast ---------- */
let toastTimer = null;
function toast(msg) {
  const t = $("#toast");
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.hidden = true), 3200);
}

/* ---------- 首页 ---------- */
async function loadHome() {
  const [ch, pr] = await Promise.all([
    fetch("/api/chapters").then((r) => r.json()),
    fetch("/api/projects").then((r) => r.json()),
  ]);
  $("#chapter-list").innerHTML = ch
    .map(
      (c) => `
    <div class="card" onclick="openChapter('${c.id}')">
      <div class="tag">${esc(c.book_chapter)}</div>
      <h3>${esc(c.title)}</h3>
      <p>${esc(c.summary)}</p>
    </div>`
    )
    .join("");
  $("#project-list").innerHTML = pr
    .map(
      (p) => `
    <div class="card" onclick="openProject('${p.id}')">
      <div class="tag">${esc(p.book_chapter)} · ${esc(p.tech)}</div>
      <h3>${esc(p.title)}</h3>
      <p>${esc(p.summary)}</p>
    </div>`
    )
    .join("");
}

/* ---------- 章节：选择小节 ---------- */
async function openChapter(id) {
  const ch = await fetch("/api/chapter/" + id).then((r) => r.json());
  currentChapter = ch;

  const sectionCards = ch.sections
    .map(
      (s, i) => `
    <div class="card" onclick="openSection(${i})">
      <div class="tag">小节 ${i + 1}</div>
      <h3>${esc(s.heading)}</h3>
    </div>`
    )
    .join("");

  const exerciseCards = ch.exercises
    .map(
      (e) => `
    <div class="card" onclick="openExercise('${e.id}')">
      <div class="tag">练习 ${esc(e.id)}</div>
      <h3>${esc(e.title)}</h3>
    </div>`
    )
    .join("");

  $("#view-chapter").innerHTML = `
    <button class="back-btn" onclick="goHome()">← 返回目录</button>
    <h1>${esc(ch.title)}</h1>
    <div class="tag">${esc(ch.book_chapter)}</div>
    <div class="chapter-summary">${esc(ch.summary)}</div>
    <h2 class="section-title">选择小节学习</h2>
    <div class="card-grid">${sectionCards}</div>
    <h2 class="section-title">动手练习</h2>
    <div class="card-grid">${exerciseCards}</div>`;
  switchView("view-chapter");
}

/* ---------- 小节学习 ---------- */
function openSection(idx) {
  const ch = currentChapter;
  const s = ch.sections[idx];
  currentSectionIndex = idx;
  const prevBtn =
    idx > 0
      ? `<button class="back-btn" onclick="openSection(${idx - 1})">← 上一节</button>`
      : "";
  const nextBtn =
    idx < ch.sections.length - 1
      ? `<button class="back-btn" onclick="openSection(${idx + 1})">下一节 →</button>`
      : "";
  const pdfPage = s.pdf_page;
  const pdfBlock = pdfPage
    ? `
    <div class="pdf-block">
      <button class="btn-small pdf-toggle" onclick="togglePdf(this)">📖 查看书中原页（第 ${pdfPage} 页）</button>
      <div class="pdf-frame-wrap hidden">
        <iframe class="pdf-page-frame" data-src="/pdf#page=${pdfPage}" title="书中原页"></iframe>
      </div>
    </div>`
    : "";
  $("#view-section").innerHTML = `
    <div class="nav-row">
      <button class="back-btn" onclick="backToChapter()">← 返回章节</button>
      ${prevBtn}${nextBtn}
    </div>
    <h1>${esc(ch.title)}</h1>
    <div class="tag">${esc(ch.book_chapter)} · 小节 ${idx + 1} / ${ch.sections.length}${pdfPage ? " · 书中第 " + pdfPage + " 页" : ""}</div>
    <div class="section-block">
      <h2>${esc(s.heading)}</h2>
      <div class="body">${esc(s.body)}</div>
    </div>
    ${pdfBlock}
    <div class="output-label">示例代码（可修改后运行）：</div>
    <textarea class="editor" id="sec-ed" spellcheck="false">${esc(s.code)}</textarea>
    <div class="btn-row">
      <button class="btn" onclick="runSection()">▶ 运行</button>
    </div>
    <div class="output" id="sec-out"></div>
    <div class="output-label">参考输出：</div>
    <pre class="code">${esc(s.output || "(运行后无文本输出)")}</pre>`;
  switchView("view-section");
  bindTabKeys();
}

window.runSection = () => {
  const code = document.getElementById("sec-ed").value;
  postRun(code, "sec-out");
};

window.togglePdf = (btn) => {
  const wrap = btn.nextElementSibling;
  const iframe = wrap.querySelector("iframe");
  if (!iframe.src) {
    iframe.src = iframe.dataset.src;
  }
  const willHide = !wrap.classList.contains("hidden");
  wrap.classList.toggle("hidden", willHide);
  btn.textContent = willHide ? "📖 查看书中原页" : "收起原页";
};

window.backToChapter = () => {
  if (currentChapter) openChapter(currentChapter.id);
};

/* ---------- 练习 ---------- */
function openExercise(id) {
  const ch = currentChapter;
  const idx = ch.exercises.findIndex((x) => x.id === id);
  const e = ch.exercises[idx];
  currentExercise = e;
  const prevBtn =
    idx > 0
      ? `<button class="back-btn" onclick="openExercise('${ch.exercises[idx - 1].id}')">← 上一题</button>`
      : "";
  const nextBtn =
    idx < ch.exercises.length - 1
      ? `<button class="back-btn" onclick="openExercise('${ch.exercises[idx + 1].id}')">下一题 →</button>`
      : "";
  $("#view-exercise").innerHTML = `
    <div class="nav-row">
      <button class="back-btn" onclick="backToChapter()">← 返回章节</button>
      ${prevBtn}${nextBtn}
    </div>
    <h1>${esc(ch.title)}</h1>
    <div class="tag">练习 ${esc(e.id)}</div>
    <div class="exercise">
      <h2>${esc(e.title)}</h2>
      <div class="prompt">${esc(e.prompt)}</div>
      <button class="hint-btn" onclick="toggleHint('${e.id}')">看提示 ▾</button>
      <div class="hint hidden" id="hint-${e.id}">${esc(e.hint)}</div>
    </div>
    <textarea class="editor" id="ed-${e.id}" spellcheck="false">${esc(e.starter || "")}</textarea>
    <div class="btn-row">
      <button class="btn" onclick="runExercise('${e.id}')">▶ 运行</button>
      <button class="btn" onclick="submitExercise('${e.id}')">提交作业</button>
      <button class="btn-secondary" onclick="gradeExercise('${e.id}')">发给 DeepSeek 批改</button>
    </div>
    <div class="output" id="out-${e.id}"></div>`;
  switchView("view-exercise");
  bindTabKeys();
}

/* ---------- 项目 ---------- */
async function openProject(id) {
  const p = await fetch("/api/project/" + id).then((r) => r.json());
  currentProject = p;
  const steps = p.steps
    .map(
      (s, i) => `
    <div class="exercise">
      <div class="tag">第 ${i + 1} 步</div>
      <h4>${esc(s.heading)}</h4>
      <div class="prompt">${esc(s.body)}</div>
      <textarea class="editor" id="ped-${id}-${i}" spellcheck="false">${esc(s.starter || s.code || "")}</textarea>
      <div class="btn-row">
        <button class="btn" onclick="runProjectStep('${id}',${i})">▶ 运行</button>
      </div>
      <div class="output" id="pout-${id}-${i}"></div>
    </div>`
    )
    .join("");
  $("#view-project").innerHTML = `
    <button class="back-btn" onclick="goHome()">← 返回目录</button>
    <h1>${esc(p.title)}</h1>
    <div class="tag">${esc(p.book_chapter)} · ${esc(p.tech)}</div>
    <div class="chapter-summary">${esc(p.summary)}<br/>环境准备：<code>${esc(p.setup)}</code></div>
    <h2 class="section-title">学习步骤</h2>
    ${steps}`;
  switchView("view-project");
  bindTabKeys();
}

/* ---------- 提示切换 ---------- */
window.toggleHint = (id) => {
  const h = document.getElementById("hint-" + id);
  h.classList.toggle("hidden");
};

/* ---------- 运行代码 ---------- */
async function postRun(code, outId) {
  const out = document.getElementById(outId);
  out.className = "output";
  out.textContent = "运行中…";
  try {
    const r = await fetch("/api/run", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code }),
    });
    const d = await r.json();
    if (d.ok) {
      out.textContent = d.output || "(无输出)";
      if (d.returncode !== 0) out.classList.add("err");
    } else {
      out.textContent = d.msg;
      out.classList.add("err");
    }
  } catch (e) {
    out.textContent = "请求失败：" + e;
    out.classList.add("err");
  }
}

window.runExercise = (id) => {
  const code = document.getElementById("ed-" + id).value;
  postRun(code, "out-" + id);
};

window.submitExercise = async (id) => {
  const e = currentExercise;
  const code = document.getElementById("ed-" + id).value;
  await fetch("/api/submissions", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ exercise_id: id, title: e.title, code }),
  });
  toast("已提交并保存：" + e.title);
};

window.gradeExercise = async (id) => {
  const e = currentExercise;
  const code = document.getElementById("ed-" + id).value;
  if (!code.trim()) {
    toast("请先写代码再批改");
    return;
  }
  const r = await fetch("/api/open_deepseek", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: e.title, prompt: e.prompt, code }),
  });
  const d = await r.json();
  toast(d.msg);
};

/* 项目步骤 */
window.runProjectStep = (id, i) => {
  const code = document.getElementById(`ped-${id}-${i}`).value;
  postRun(code, `pout-${id}-${i}`);
};

/* ---------- 作业 ---------- */
async function loadHomework() {
  const subs = await fetch("/api/submissions").then((r) => r.json());
  const box = $("#homework-list");
  if (!subs.length) {
    box.innerHTML = '<p class="lead">还没有提交过作业。去章节里写代码并“提交作业”吧。</p>';
    return;
  }
  box.innerHTML = subs
    .slice()
    .reverse()
    .map(
      (s) => `
    <div class="hw-item">
      <div class="hw-meta">${esc(s.time)} · ${esc(s.title)}（${esc(s.exercise_id)}）</div>
      <details>
        <summary>查看代码</summary>
        <pre class="code">${esc(s.code)}</pre>
      </details>
    </div>`
    )
    .join("");
}

/* ---------- 设置 ---------- */
async function loadSettings() {
  const s = await fetch("/api/settings").then((r) => r.json());
  $("#pdf-path").value = s.pdf_path || "";
}
async function saveSettings() {
  const body = { pdf_path: $("#pdf-path").value };
  await fetch("/api/settings", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  toast("设置已保存");
}

/* ---------- 文件选择（原生对话框） ---------- */
async function chooseFile() {
  const d = await fetch("/api/choose_file", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ kind: "pdf" }),
  }).then((r) => r.json());
  if (d.path) {
    $("#pdf-path").value = d.path;
  } else if (d.error) {
    toast("无法打开文件对话框，请手动填写路径");
  }
}

/* ---------- 编辑器 Tab 键 ---------- */
function bindTabKeys() {
  document.querySelectorAll("textarea.editor").forEach((ta) => {
    ta.addEventListener("keydown", (e) => {
      if (e.key === "Tab") {
        e.preventDefault();
        const s = ta.selectionStart,
          en = ta.selectionEnd;
        ta.value = ta.value.slice(0, s) + "    " + ta.value.slice(en);
        ta.selectionStart = ta.selectionEnd = s + 4;
      }
    });
  });
}

/* ---------- 绑定 & 启动 ---------- */
function init() {
  document.querySelectorAll(".nav-btn").forEach((b) =>
    b.addEventListener("click", () => switchView(b.dataset.view))
  );
  $("#pdf-reload").addEventListener("click", reloadPdf);
  $("#settings-save").addEventListener("click", saveSettings);
  $("#pdf-choose").addEventListener("click", chooseFile);
  loadHome();
  switchView("home");
}
document.addEventListener("DOMContentLoaded", init);
