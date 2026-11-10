#!/usr/bin/env python3
"""Validate and package the single website source tree for manual publishing."""

import argparse
import hashlib
import json
import stat
import time
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
WEBSITE = ROOT / "website"
REQUIRED_PAGES = {
    "index.html", "appstore-marketing.html", "privacy.html",
    "subscription-terms.html", "support.html", "contact.html",
}
LANGUAGES = ("zh-CN", "zh-TW", "en", "ja", "ko", "vi", "id", "th")
LOCALIZED_PAGES = {"i18n/{}/{}".format(language, page)
                   for language in LANGUAGES for page in REQUIRED_PAGES}


class PageResources(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.ids = set()
        self.inline_icon = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get("id"):
            self.ids.add(attrs["id"])
        for attribute in ("href", "src"):
            if attrs.get(attribute):
                self.links.append(attrs[attribute])
        if tag == "link" and "icon" in attrs.get("rel", ""):
            self.inline_icon |= attrs.get("href", "").startswith("data:")


def collect_and_validate():
    pages = {path.relative_to(WEBSITE).as_posix(): path for path in WEBSITE.rglob("*.html")}
    missing = (REQUIRED_PAGES | LOCALIZED_PAGES) - pages.keys()
    if missing:
        raise ValueError("Missing website pages: " + ", ".join(sorted(missing)))
    paths = list(pages.values()) + [WEBSITE / "favicon.ico"]
    paths += [path for path in (WEBSITE / "assets").rglob("*") if path.is_file()]
    files = {}
    for path in sorted(paths):
        if path.is_symlink() or not path.is_file():
            raise ValueError("Missing resource or unsupported symlink: " + str(path))
        files[path.relative_to(WEBSITE).as_posix()] = path.read_bytes()

    # Distinct sizes are useful; byte-identical icons under different names
    # recreate the source duplication this directory is intended to remove.
    icon_hashes = {}
    for name, data in files.items():
        if Path(name).suffix.lower() not in (".png", ".ico", ".jpg", ".jpeg", ".svg", ".webp"):
            continue
        digest = hashlib.sha256(data).hexdigest()
        if digest in icon_hashes:
            raise ValueError("Duplicate resources: " + icon_hashes[digest] + " and " + name)
        icon_hashes[digest] = name

    parsed = {}
    for name, path in pages.items():
        parser = PageResources()
        parser.feed(path.read_text(encoding="utf-8"))
        if parser.inline_icon:
            raise ValueError(name + ": use a shared favicon file instead of an inline copy")
        parsed[name] = parser

    for name, parser in parsed.items():
        for link in parser.links:
            url = urlsplit(link)
            if url.scheme and url.scheme not in ("http", "https"):
                continue
            if url.netloc and url.hostname != "sdnlink.cn":
                continue
            if url.netloc:
                relative = unquote(url.path).lstrip("/") or "index.html"
            elif not url.path:
                relative = name
            else:
                candidate = (pages[name].parent / unquote(url.path)).resolve()
                if url.path.startswith("/"):
                    candidate = (WEBSITE / unquote(url.path).lstrip("/")).resolve()
                try:
                    relative = candidate.relative_to(WEBSITE).as_posix()
                except ValueError:
                    raise ValueError(name + ": link escapes website/: " + link)
            if relative not in files:
                raise ValueError(name + ": missing resource: " + link)
            if url.fragment and relative in parsed and unquote(url.fragment) not in parsed[relative].ids:
                raise ValueError(name + ": missing section: " + link)
    return files


def package(files, destination):
    destination = destination.resolve()
    if WEBSITE == destination or WEBSITE in destination.parents:
        raise ValueError("Write generated archives outside website/, for example dist/")
    manifest = {
        "site": "https://sdnlink.cn",
        "urls": {
            "privacy": "https://sdnlink.cn/privacy.html",
            "terms": "https://sdnlink.cn/subscription-terms.html",
            "support": "https://sdnlink.cn/support.html",
            "contact": "https://sdnlink.cn/contact.html",
        },
        "files": {name: hashlib.sha256(data).hexdigest() for name, data in files.items()},
    }
    instructions = """sdnlink.cn 官网手动发布

发布前备份服务器现有文件。将压缩包内容解压到静态站点根目录，
不要增加 website/ 或 docs/ 前缀。根入口、i18n/、assets/ 和 favicon.ico 一起发布。
不要上传仓库根目录的兼容跳转页，也不要重新复制旧的图标目录。

发布包已设置目录权限 755、文件权限 644。若旧图片返回 403，
重新解压本包后，在服务器站点根目录执行以下命令修复可能保留的旧权限：
find assets i18n -type d -exec chmod 755 {} +
find assets i18n -type f -exec chmod 644 {} +
chmod 644 *.html favicon.ico

隐私政策：https://sdnlink.cn/privacy.html
订阅条款：https://sdnlink.cn/subscription-terms.html
服务支持：https://sdnlink.cn/support.html
联系我们：https://sdnlink.cn/contact.html

发布后检查上述页面、八种语言、导航及图标，按 manifest.json 核对文件 SHA-256。
App Store Connect 的隐私政策、EULA 和服务支持网址使用上面的正式地址。
本工具只生成发布包，不会自动修改服务器或 App Store Connect。
"""
    destination.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
        def write_public_entry(name, data):
            entry = ZipInfo(name, date_time=time.localtime()[:6])
            entry.create_system = 3  # Unix permissions must survive unzip.
            entry.compress_type = ZIP_DEFLATED
            mode = (stat.S_IFDIR | 0o755) if name.endswith("/") else (stat.S_IFREG | 0o644)
            entry.external_attr = mode << 16
            if name.endswith("/"):
                entry.external_attr |= 0x10
            archive.writestr(entry, data)

        # Explicit directory entries keep newly created assets/ readable even
        # with a restrictive umask. unzip can retain an existing directory's
        # permissions; publishing instructions include a remedy for that case.
        directories = set()
        for name in files:
            for parent in Path(name).parents:
                if parent != Path("."):
                    directories.add(parent.as_posix() + "/")
        for name in sorted(directories):
            write_public_entry(name, b"")
        for name, data in files.items():
            write_public_entry(name, data)
        write_public_entry("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
        write_public_entry("发布说明.txt", instructions)
    with ZipFile(destination) as archive:
        if archive.testzip() is not None:
            raise ValueError("Archive integrity check failed")
        for entry in archive.infolist():
            expected = 0o755 if entry.is_dir() else 0o644
            if stat.S_IMODE(entry.external_attr >> 16) != expected:
                raise ValueError("Incorrect publishing permissions: " + entry.filename)
        for name, digest in manifest["files"].items():
            if hashlib.sha256(archive.read(name)).hexdigest() != digest:
                raise ValueError("Archive checksum mismatch: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate without creating an archive")
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "sdnlink-website.zip")
    args = parser.parse_args()
    try:
        files = collect_and_validate()
        print("Validated {} website files; no missing links or duplicate icons".format(len(files)))
        if not args.check:
            package(files, args.output)
            print("Created " + str(args.output.resolve()))
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
