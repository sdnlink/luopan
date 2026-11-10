"use strict";

(() => {
    const languages = ["zh-CN", "zh-TW", "en", "ja", "ko", "vi", "id", "th"];
    const storageKey = "tianji.website.language";

    function supportedLanguage(value) {
        if (typeof value !== "string") return null;
        const language = value.toLowerCase().replace(/_/g, "-");
        if (language === "zh" || /^zh-(cn|sg|hans)(-|$)/.test(language)) return "zh-CN";
        if (/^zh-(tw|hk|mo|hant)(-|$)/.test(language)) return "zh-TW";
        const base = language.split("-")[0];
        return languages.includes(base) ? base : null;
    }

    function remember(language) {
        try { window.localStorage.setItem(storageKey, language); } catch (_) {}
    }

    function preferredLanguage() {
        try { return supportedLanguage(window.localStorage.getItem(storageKey)); }
        catch (_) { return null; }
    }

    document.querySelectorAll("[data-site-language]").forEach(link => {
        link.addEventListener("click", () => remember(link.dataset.siteLanguage));
    });

    const header = document.querySelector(".site-header");
    if (header && typeof ResizeObserver === "function") {
        const observer = new ResizeObserver(() => {
            document.documentElement.style.setProperty("--header-height", `${Math.ceil(header.getBoundingClientRect().height)}px`);
        });
        observer.observe(header);
    }

    const languageMenu = document.querySelector(".language-menu");
    if (languageMenu) {
        document.addEventListener("click", event => {
            if (!languageMenu.contains(event.target)) languageMenu.open = false;
        });
        document.addEventListener("keydown", event => {
            if (event.key === "Escape" && languageMenu.open) {
                languageMenu.open = false;
                languageMenu.querySelector("summary").focus();
            }
        });
    }

    // Each localized page already contains its complete language and works
    // without JavaScript. Only the stable legacy URLs need automatic routing.
    if (document.body.dataset.entry !== "true") return;
    const url = new URL(window.location.href);
    const browserLanguages = Array.from(navigator.languages || [navigator.language]);
    const language = supportedLanguage(url.searchParams.get("lang"))
        || supportedLanguage(url.hash.slice(1)) || preferredLanguage()
        || browserLanguages.map(supportedLanguage).find(Boolean) || "zh-CN";
    const target = new URL(`i18n/${language}/${document.body.dataset.page}`, url);
    url.searchParams.delete("lang");
    target.search = url.search;
    if (!supportedLanguage(url.hash.slice(1))) target.hash = url.hash;
    window.location.replace(target.href);
})();
