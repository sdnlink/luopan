#!/usr/bin/env python3
"""Catch references to repository types omitted from an Xcode source phase.

This checks local type availability, not Swift semantics or framework imports.
Run xcodebuild as well: lexical checks cannot replace compiling each target.
"""
from pathlib import Path
import re
import sys

from validate_swift_syntax import clean_code


IOS = Path(__file__).resolve().parents[1] / "ios"
PROJECT = IOS / "TiandiLuopan.xcodeproj" / "project.pbxproj"
ROOTS = [IOS / "TiandiLuopan", IOS / "TiandiLuopanWidget"]


def source_phases(project):
    references = dict(re.findall(
        r'(\w+) /\* .*? \*/ = \{isa = PBXFileReference;[^\n]*?path = "?([^";]+)"?;', project))
    build_files = dict(re.findall(
        r'(\w+) /\* .*? \*/ = \{isa = PBXBuildFile; fileRef = (\w+)', project))
    phases = re.findall(
        r'\w+ /\* ([^\n]+) \*/ = \{\s*isa = PBXSourcesBuildPhase;.*?files = \((.*?)\);', project, re.S)
    result = {}
    for name, body in phases:
        if name == "Test Sources":
            continue  # Tests import the app module with @testable.
        paths = []
        for entry in re.findall(r'(\w+) /\*', body):
            path = references[build_files[entry]]
            matches = [root / path for root in ROOTS if (root / path).is_file()]
            if len(matches) != 1:
                raise ValueError("{}: cannot resolve source {}".format(name, path))
            paths.append(matches[0])
        if len(paths) != len(set(paths)):
            raise ValueError("{}: duplicate compilation entries".format(name))
        result[name] = set(paths)
    if not {"Sources", "Widget Sources"}.issubset(result):
        raise ValueError("App and widget source phases must both be checked")
    return result


def check(project):
    phases = source_phases(project)
    declarations = {}
    tokens = {}
    for root in ROOTS:
        for path in root.rglob("*.swift"):
            source = clean_code(path.read_text(encoding="utf-8"))
            tokens[path] = set(re.findall(r'\b[A-Za-z_]\w*\b', source))
            for name in re.findall(r'\b(?:struct|class|enum|protocol|typealias)\s+([A-Za-z_]\w*)', source):
                declarations.setdefault(name, set()).add(path)
    errors = []
    for phase, paths in phases.items():
        for path in sorted(paths):
            for name in sorted(tokens[path] & declarations.keys()):
                if not (declarations[name] & paths):
                    errors.append("{}: {} references local type {} outside this target".format(
                        phase, path.relative_to(IOS), name))
    return phases, errors


def main():
    try:
        phases, errors = check(PROJECT.read_text(encoding="utf-8"))
    except (KeyError, ValueError) as error:
        print("[ERROR] {}".format(error))
        return 1
    for error in errors:
        print("[ERROR] " + error)
    print("Checked {} source phases ({} compilation entries); {} unavailable local types".format(
        len(phases), sum(len(paths) for paths in phases.values()), len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
