"""Validate the checked-in iOS project without destroying its build graph.

The project used to be generated from a four-file bootstrap template. The
template became stale as the native app grew and running this helper removed
new Swift sources, frameworks, and localized resources from the target. The
Xcode project is now maintained as the canonical artifact; this helper only
performs a safe structural check.
"""

from pathlib import Path


REQUIRED_MARKERS = (
    "StoreKitIAPManager.swift in Sources",
    "WorldMagneticModel.swift in Sources",
    "OnDeviceShaAnalyzer.swift in Sources",
    "InfoPlist.strings in Resources",
    "Vision.framework in Frameworks",
    "Photos.framework in Frameworks",
    "en,",
    "zh-Hans,",
    "zh-Hant,",
)


def generate_pbxproj() -> None:
    project_file = Path(__file__).resolve().parents[1] / "ios" / "TiandiLuopan.xcodeproj" / "project.pbxproj"
    if not project_file.is_file():
        raise FileNotFoundError(f"Missing checked-in Xcode project: {project_file}")

    content = project_file.read_text(encoding="utf-8")
    missing = [marker for marker in REQUIRED_MARKERS if marker not in content]
    if missing:
        joined = ", ".join(missing)
        raise RuntimeError(f"Xcode project is missing required build configuration: {joined}")

    print(f"Xcode project validated and preserved: {project_file}")


if __name__ == "__main__":
    generate_pbxproj()
