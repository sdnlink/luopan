# 天机演象

仓库包含移动应用、官网和开发记录：

| 目录 | 内容 |
| --- | --- |
| [website/](website/) | sdnlink.cn 官网及八语言独立页面的唯一源码目录 |
| [docs/](docs/) | 代码审查、功能设计和发布记录 |
| [tools/](tools/) | 官网检查及发布打包工具 |
| [tiandi_luopan/](tiandi_luopan/) | Android、iOS 应用及对应工具，详见其 README |
| [tiandi_luopan_mini_program/](tiandi_luopan_mini_program/) | 微信小程序 |

官网本地预览：

```sh
python3 -m http.server 8000 --directory website
```

官网检查与打包：

```sh
python3 tools/package_website.py --check
python3 -m unittest discover -s tools -p 'test_package_website.py'
python3 tools/package_website.py
```

将 `dist/sdnlink-website.zip` 中的内容发布到服务器站点根目录，具体见 [官网发布说明](website/README.md)。仓库根目录的 `index.html` 仅提供兼容跳转。
