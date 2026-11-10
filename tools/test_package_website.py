"""Ensure manual website releases remain readable by the web server."""

import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path
from html.parser import HTMLParser
from zipfile import ZipFile

from package_website import WEBSITE, LANGUAGES, REQUIRED_PAGES, collect_and_validate, package


class WebsitePublishingTests(unittest.TestCase):
    def test_all_page_languages_are_independent_and_share_the_same_styles(self):
        class LocalizedPage(HTMLParser):
            def __init__(self):
                super().__init__()
                self.language = None
                self.language_links = {}
                self.styles = []
                self.inline_styles = False
                self.headings = 0
                self.header = False
                self.header_links = []
                self.current_links = []

            def handle_starttag(self, tag, attrs):
                attrs = dict(attrs)
                if tag == "html": self.language = attrs.get("lang")
                if tag == "h1": self.headings += 1
                if tag == "style": self.inline_styles = True
                if tag == "header": self.header = True
                if tag == "link" and attrs.get("rel") == "stylesheet":
                    self.styles.append(attrs["href"])
                if tag == "a" and "data-site-language" in attrs:
                    self.language_links[attrs["data-site-language"]] = attrs["href"]
                if tag == "a" and self.header and "data-site-language" not in attrs and attrs.get("class") != "brand":
                    self.header_links.append(attrs.get("href"))
                    if attrs.get("aria-current") == "page":
                        self.current_links.append(attrs["href"])

            def handle_endtag(self, tag):
                if tag == "header": self.header = False

        for language in LANGUAGES:
            for page in REQUIRED_PAGES:
                with self.subTest(language=language, page=page):
                    path = WEBSITE / "i18n" / language / page
                    document = path.read_text(encoding="utf-8")
                    parsed = LocalizedPage()
                    parsed.feed(document)
                    self.assertEqual(parsed.language, language)
                    self.assertEqual(parsed.headings, 1)
                    self.assertFalse(parsed.inline_styles)
                    self.assertNotIn("data-i18n=", document)
                    self.assertNotIn("tel:", document)
                    self.assertEqual(parsed.styles, ["../../assets/site.css"])
                    self.assertEqual(set(parsed.language_links), set(LANGUAGES))
                    for target_language, link in parsed.language_links.items():
                        self.assertEqual((path.parent / link).resolve(),
                                         (WEBSITE / "i18n" / target_language / page).resolve())
                    self.assertNotIn("#compliance", parsed.header_links)
                    self.assertEqual(parsed.header_links, ["index.html", "appstore-marketing.html", "support.html",
                                                          "privacy.html", "subscription-terms.html", "contact.html"])
                    self.assertEqual(parsed.current_links, [page])
        files = collect_and_validate()
        self.assertIn("assets/site.js", files)
        self.assertIn("assets/site.css", files)
        self.assertEqual(len([name for name in files if name.endswith(".html")]), 54)

    def test_page_bodies_have_their_own_purpose_and_contact_has_its_own_page(self):
        import re

        for language in LANGUAGES:
            def main(page):
                content = (WEBSITE / "i18n" / language / page).read_text(encoding="utf-8")
                return re.search(r"<main\b.*?</main>", content, re.S)[0]

            product = main("appstore-marketing.html")
            self.assertEqual(product.count('class="feature-card"'), 6, language)
            self.assertIn('class="section product-requirements"', product)
            for marker in ["support-faq", "developer-contact", "mailto:", "tel:", "privacy.html", "subscription-terms.html"]:
                self.assertNotIn(marker, product, language)

            support = main("support.html")
            self.assertEqual(support.count('class="support-faq"'), 5, language)
            self.assertIn('href="contact.html"', support)
            for marker in ["contact-channels", "developer-contact", "feature-grid", "mailto:", "tel:"]:
                self.assertNotIn(marker, support, language)

            home = main("index.html")
            for marker in ["support-faq", "developer-contact", "mailto:", "tel:"]:
                self.assertNotIn(marker, home, language)

            contact = main("contact.html")
            self.assertIn('class="contact-channels"', contact)
            self.assertIn('href="mailto:support@sdnlink.cn"', contact)
            channels = re.search(r'<div class="contact-channels">(.*?)</div>', contact, re.S)[1]
            self.assertEqual(re.findall(r'href="([^"]+)"', channels), ["mailto:support@sdnlink.cn"])
            self.assertIn("北京市海淀区海淀大街甲36号5层5014号-970号", contact)
            self.assertNotIn("support-faq", contact)

    def test_root_policy_urls_keep_all_language_destinations_available(self):
        for page in REQUIRED_PAGES:
            content = (WEBSITE / page).read_text(encoding="utf-8")
            self.assertIn('data-entry="true"', content)
            for language in LANGUAGES:
                self.assertIn('href="i18n/' + language + '/' + page + '"', content)

    def test_all_archive_entries_have_public_read_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            archive_path = Path(directory) / "site.zip"
            package(collect_and_validate(), archive_path)
            with ZipFile(archive_path) as archive:
                self.assertTrue(archive.getinfo("assets/").is_dir())
                for entry in archive.infolist():
                    expected = 0o755 if entry.is_dir() else 0o644
                    self.assertEqual(stat.S_IMODE(entry.external_attr >> 16), expected, entry.filename)
                self.assertEqual(archive.read("assets/icon.png"), (WEBSITE / "assets/icon.png").read_bytes())

    @unittest.skipUnless(os.name == "posix" and shutil.which("unzip"), "Requires Unix unzip")
    def test_unzip_creates_readable_files_and_directories_with_private_umask(self):
        with tempfile.TemporaryDirectory() as directory:
            archive_path = Path(directory) / "site.zip"
            target = Path(directory) / "published"
            package(collect_and_validate(), archive_path)
            subprocess.run(["unzip", "-oq", str(archive_path), "-d", str(target)],
                           check=True, preexec_fn=lambda: os.umask(0o077),
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(stat.S_IMODE((target / "assets").stat().st_mode), 0o755)
            for name in ["i18n", "i18n/en", "i18n/zh-CN"]:
                self.assertEqual(stat.S_IMODE((target / name).stat().st_mode), 0o755, name)
            for name in ["assets/icon.png", "assets/favicon-32x32.png", "assets/site.css", "assets/site.js",
                         "favicon.ico", "index.html", "support.html", "contact.html", "i18n/en/privacy.html",
                         "i18n/zh-CN/index.html", "i18n/ja/contact.html"]:
                self.assertEqual(stat.S_IMODE((target / name).stat().st_mode), 0o644, name)
                self.assertEqual((target / name).read_bytes(), (WEBSITE / name).read_bytes(), name)

    @unittest.skipUnless(os.name == "posix" and shutil.which("unzip"), "Requires Unix unzip")
    def test_redeploy_fixes_private_files_and_documented_command_fixes_old_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            archive_path = Path(directory) / "site.zip"
            target = Path(directory) / "published"
            (target / "assets").mkdir(parents=True)
            (target / "assets").chmod(0o700)
            icon = target / "assets/icon.png"
            icon.write_bytes(b"previous upload")
            icon.chmod(0o600)
            package(collect_and_validate(), archive_path)
            subprocess.run(["unzip", "-oq", str(archive_path), "-d", str(target)],
                           check=True, preexec_fn=lambda: os.umask(0o077),
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(stat.S_IMODE(icon.stat().st_mode), 0o644)
            # unzip retains existing directory permissions. This is the same
            # targeted repair documented for an already-published site.
            subprocess.run(["chmod", "755", "assets"], cwd=target, check=True)
            self.assertEqual(stat.S_IMODE((target / "assets").stat().st_mode), 0o755)
            self.assertEqual(icon.read_bytes(), (WEBSITE / "assets/icon.png").read_bytes())


if __name__ == "__main__":
    unittest.main()
