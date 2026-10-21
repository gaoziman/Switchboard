#!/usr/bin/env python3
"""界面文字的字符串表（App/macOS/Resources/Localizable.xcstrings，源语言中文，另有英文）。

  scripts/l10n.py sync                 # 带 SWIFT_EMIT_LOC_STRINGS 构建一次，把编译器抽出的中文 key 同步进表：新增补上、没人用的删掉
  scripts/l10n.py sync --no-build      # 用上次构建抽出的结果
  scripts/l10n.py missing [out.json]   # 列出还没有英文的 key（写成 {key: ""} 方便填）
  scripts/l10n.py import en.json       # 把 {key: 英文} 写进表；值可以是 {"one": …, "other": …} 表示复数
  scripts/l10n.py check                # 有 key 没英文、或英文的占位符和 key 对不上 → 退出码 1

只收 Screens 和 app 两个 target；MockData / ProductScreens（截图用的假数据）不收。
"""
import glob, json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "App/macOS/Resources/Localizable.xcstrings")
DERIVED = os.path.join(ROOT, ".build/loc")
SKIP_SOURCES = ("MockData.swift", "ProductScreens.swift")
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|lf|f|\.\d+f|%)")


def load():
    if os.path.exists(CATALOG):
        return json.load(open(CATALOG))
    return {"sourceLanguage": "zh-Hans", "strings": {}, "version": "1.0"}


def save(cat):
    cat["strings"] = dict(sorted(cat["strings"].items()))
    with open(CATALOG, "w") as f:
        json.dump(cat, f, ensure_ascii=False, indent=2, separators=(",", " : "))
        f.write("\n")


def build():
    env = dict(os.environ)
    cmd = ["xcodebuild", "-skipPackagePluginValidation", "-skipMacroValidation", "-project", "Switchboard.xcodeproj",
           "-scheme", "Switchboard-macOS", "-configuration", "Debug", "-destination", "platform=macOS,arch=" + os.uname().machine,
           "-derivedDataPath", DERIVED, "SWIFT_EMIT_LOC_STRINGS=YES", "CODE_SIGNING_ALLOWED=NO", "build"]
    os.makedirs(os.path.join(ROOT, ".build/logs"), exist_ok=True)
    with open(os.path.join(ROOT, ".build/logs/l10n.log"), "w") as log:
        if subprocess.call(cmd, cwd=ROOT, stdout=log, stderr=log, env=env) != 0:
            sys.exit("构建失败，见 .build/logs/l10n.log")


def extracted():
    keys = {}
    for f in glob.glob(os.path.join(DERIVED, "Build/Intermediates.noindex/**/*.stringsdata"), recursive=True):
        if not ("/Screens-t.build/" in f or "/Switchboard.build/" in f):
            continue
        d = json.load(open(f))
        src = d.get("source", "")
        if src.endswith(SKIP_SOURCES):
            continue
        for table, entries in d.get("tables", {}).items():
            if table != "Localizable":
                continue
            for e in entries:
                keys.setdefault(e["key"], []).append(f"{os.path.relpath(src, ROOT)}:{e['location']['startingLine']}")
    return keys


def has_cjk(s):
    return re.search("[一-鿿]", s) is not None


def english(entry):
    loc = entry.get("localizations", {}).get("en")
    if not loc:
        return None
    if "stringUnit" in loc:
        return [loc["stringUnit"]["value"]]
    plural = loc.get("variations", {}).get("plural", {})
    return [v["stringUnit"]["value"] for v in plural.values()] or None


def specs(s):
    return sorted(re.sub(r"\d+\$", "", m) for m in SPEC.findall(s) if m != "%%")


def cmd_sync(no_build):
    if not no_build:
        build()
    keys = extracted()
    cat = load()
    strings = cat["strings"]
    added = [k for k in keys if has_cjk(k) and k not in strings]
    for k in added:
        strings[k] = {}
    removed = [k for k in list(strings) if k not in keys]
    for k in removed:
        del strings[k]
    save(cat)
    print(f"字符串表：{len(strings)} 条（新增 {len(added)}，删掉 {len(removed)}）")
    missing = [k for k, v in strings.items() if not english(v)]
    print(f"还没有英文：{len(missing)} 条")


def cmd_missing(out):
    cat = load()
    missing = {k: "" for k, v in cat["strings"].items() if not english(v)}
    if out:
        json.dump(missing, open(out, "w"), ensure_ascii=False, indent=1)
        print(f"{len(missing)} 条写到 {out}")
    else:
        for k in missing:
            print(k)


def cmd_import(path):
    cat = load()
    data = json.load(open(path))
    n = 0
    for k, v in data.items():
        if k not in cat["strings"] or not v:
            continue
        if isinstance(v, dict):
            cat["strings"][k]["localizations"] = {"en": {"variations": {"plural": {
                form: {"stringUnit": {"state": "translated", "value": text}} for form, text in v.items()}}}}
        else:
            cat["strings"][k]["localizations"] = {"en": {"stringUnit": {"state": "translated", "value": v}}}
        n += 1
    save(cat)
    print(f"写入 {n} 条英文")


def cmd_check():
    cat = load()
    bad = 0
    for k, v in cat["strings"].items():
        en = english(v)
        if not en:
            print(f"没有英文：{k}")
            bad += 1
            continue
        for text in en:
            if has_cjk(text):
                print(f"英文里还有中文：{k} → {text}")
                bad += 1
            # 复数的 one 可以不写数字
            if specs(text) != specs(k) and not (len(en) > 1 and set(specs(text)) <= set(specs(k))):
                print(f"占位符对不上：{k} → {text}")
                bad += 1
    print("通过" if bad == 0 else f"{bad} 个问题")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    c = args[0]
    if c == "sync":
        cmd_sync("--no-build" in args)
    elif c == "missing":
        cmd_missing(args[1] if len(args) > 1 else None)
    elif c == "import":
        cmd_import(args[1])
    elif c == "check":
        cmd_check()
    else:
        sys.exit(__doc__)
