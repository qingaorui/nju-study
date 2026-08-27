# -*- coding: utf-8 -*-
"""作业提交历史，存于 data/submissions.json。"""
import json
import os

from src import settings

SUB_PATH = os.path.join(settings.DATA_DIR, "submissions.json")


def load_submissions():
    if os.path.exists(SUB_PATH):
        try:
            with open(SUB_PATH, encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return []
    return []


def add_submission(rec):
    subs = load_submissions()
    subs.append(rec)
    with open(SUB_PATH, "w", encoding="utf-8") as f:
        json.dump(subs, f, ensure_ascii=False, indent=2)
    return subs
