import http.server
import socketserver
import socket
import os

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # doesn't even have to be reachable
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def start_server(port=8080):
    web_dir = os.path.abspath("ios/TiandiLuopan/www")
    os.chdir(web_dir)
    
    class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
        def end_headers(self):
            self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            super().end_headers()

    with socketserver.TCPServer(("", port), NoCacheHandler) as httpd:
        local_ip = get_local_ip()
        print("=" * 60)
        print("  演象·时空罗盘 (iOS PWA / Web 局域网真机调试服务器)")
        print("=" * 60)
        print(f" 本机预览:   http://localhost:{port}/")
        print(f" iPhone访问: http://{local_ip}:{port}/")
        print("=" * 60)
        print(" 提示: 在 iPhone Safari 浏览器打开上述链接，")
        print(" 点击底部分享按钮 -> 选择【添加到主屏幕】，即可全屏免签体验！")
        print(" 按 Ctrl + C 可停止服务器。")
        print("=" * 60)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n服务器已停止。")

if __name__ == "__main__":
    start_server()
