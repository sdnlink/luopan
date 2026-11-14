#!/usr/bin/env python3
"""Synchronize canonical iOS translations and record an immutable port baseline."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ("zhHans", "zhHant", "en", "th", "vi", "id", "ja", "ko")


def translations(source):
    result = {language: {} for language in LANGUAGES}
    language = None
    for line in source.splitlines():
        header = re.match(r"^        \.(zhHans|zhHant|en|th|vi|id|ja|ko): \[", line)
        if header:
            language = header[1]
        entry = re.match(r'^\s*"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$', line)
        if language and entry:
            key, value = (json.loads('"' + token + '"') for token in entry.groups())
            if key in result[language]:
                raise ValueError(f"Duplicate translation: {language}.{key}")
            result[language][key] = value
    expected = set(result[LANGUAGES[0]])
    if not expected or any(set(table) != expected for table in result.values()):
        raise ValueError("iOS translation tables do not have matching key sets")
    return result


def git(*arguments):
    return subprocess.check_output(["git", *arguments], cwd=ROOT)


def sync(revision):
    commit = git("rev-parse", revision).decode().strip()
    prefix = "tiandi_luopan/ios/"
    source = git("show", f"{commit}:{prefix}TiandiLuopan/Models/LocalizationManager.swift").decode()
    canonical = translations(source)
    destination = ROOT / "app/src/main/assets/i18n.json"
    previous = json.loads(destination.read_text())
    for language, table in canonical.items():
        previous.setdefault(language, {}).update(table)
    destination.write_text(json.dumps(previous, ensure_ascii=False, indent=2) + "\n")
    paths = git("ls-tree", "-r", "--name-only", commit, "ios").decode().splitlines()
    sources = []
    for path in paths:
        if not path.endswith(".swift"):
            continue
        absolute = path if path.startswith("tiandi_luopan/") else "tiandi_luopan/" + path
        data = git("show", f"{commit}:{absolute}")
        sources.append({"source": absolute, "sha256": hashlib.sha256(data).hexdigest()})
    manifest = {"iosCommit": commit, "translationKeysPerLanguage": len(canonical["en"]), "sources": sources}
    (ROOT / "app/src/main/assets/ios_port_baseline.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Synced {len(canonical['en'])} iOS keys in 8 languages; recorded {len(sources)} Swift sources from {commit}")


def check(revision):
    commit = git("rev-parse", revision).decode().strip()
    canonical = translations(git("show", commit + ":tiandi_luopan/ios/TiandiLuopan/Models/LocalizationManager.swift").decode())
    actual = json.loads((ROOT / "app/src/main/assets/i18n.json").read_text())
    for language, values in canonical.items():
        for key, value in values.items():
            if actual[language].get(key) != value:
                raise ValueError("iOS translation differs: " + language + "." + key)
    keys = set(actual["en"])
    if any(set(values) != keys for values in actual.values()):
        raise ValueError("Android language tables differ")
    manifest = json.loads((ROOT / "app/src/main/assets/ios_port_baseline.json").read_text())
    inventory = json.loads((ROOT / "docs/android_port_inventory.json").read_text())
    expected = {row["source"].split("tiandi_luopan/", 1)[1]: row["sha256"] for row in manifest["sources"]}
    covered = {row["ios"]: row["sha256"] for row in inventory["sources"]}
    if expected != covered:
        raise ValueError("Swift source inventory does not match the baseline")
    for path, digest in expected.items():
        data = git("show", commit + ":tiandi_luopan/" + path)
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError("iOS baseline changed: " + path)
    for row in inventory["sources"]:
        if not row["android"] or any(not (ROOT / path).is_file() for path in row["android"]):
            raise ValueError("Android counterpart missing: " + row["ios"])
    print("Validated %d Swift source mappings, %d canonical iOS keys and %d total keys in 8 languages" % (len(expected), len(canonical["en"]), len(keys)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--revision", default="main")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    (check if args.check else sync)(args.revision)
