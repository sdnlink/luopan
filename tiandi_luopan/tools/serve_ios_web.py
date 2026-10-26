import http.server
import socketserver
import socket
import ssl
import os
import threading
import datetime
import ipaddress

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def generate_self_signed_cert(cert_path, key_path, ip_str):
    try:
        from cryptography import x509
        from cryptography.x509.oid import NameOID
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import rsa

        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, f"YanXiang Compass")
        ])
        
        sans = [
            x509.DNSName("localhost"),
            x509.IPAddress(ipaddress.IPv4Address("127.0.0.1"))
        ]
        try:
            sans.append(x509.IPAddress(ipaddress.IPv4Address(ip_str)))
        except Exception:
            pass

        cert = x509.CertificateBuilder().subject_name(
            subject
        ).issuer_name(
            issuer
        ).public_key(
            key.public_key()
        ).serial_number(
            x509.random_serial_number()
        ).not_valid_before(
            datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1)
        ).not_valid_after(
            datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=365)
        ).add_extension(
            x509.SubjectAlternativeName(sans),
            critical=False,
        ).sign(key, hashes.SHA256())

        os.makedirs(os.path.dirname(cert_path), exist_ok=True)
        with open(key_path, "wb") as f:
            f.write(key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            ))
        with open(cert_path, "wb") as f:
            f.write(cert.public_bytes(serialization.Encoding.PEM))
        return True
    except Exception as e:
        print(f"Warning: Could not generate SSL certificate: {e}")
        return False

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

    def guess_type(self, path):
        ctype = super().guess_type(path)
        if ctype.startswith('text/html'):
            return 'text/html; charset=utf-8'
        if ctype.startswith('application/javascript') or ctype.startswith('text/javascript'):
            return 'application/javascript; charset=utf-8'
        if ctype.startswith('text/'):
            return f"{ctype}; charset=utf-8"
        return ctype

def start_server(http_port=8080, https_port=8443):
    web_dir = os.path.abspath("ios/TiandiLuopan/www")
    os.chdir(web_dir)
    local_ip = get_local_ip()

    cert_dir = os.path.abspath("../../.cert")
    cert_path = os.path.join(cert_dir, "cert.pem")
    key_path = os.path.join(cert_dir, "key.pem")

    has_ssl = False
    if not (os.path.exists(cert_path) and os.path.exists(key_path)):
        has_ssl = generate_self_signed_cert(cert_path, key_path, local_ip)
    else:
        has_ssl = True

    # 1. Start HTTP Server in background thread
    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.TCPServer(("", http_port), NoCacheHandler)
    t_http = threading.Thread(target=httpd.serve_forever, daemon=True)
    t_http.start()

    # 2. Start HTTPS Server if SSL available
    httpsd = None
    if has_ssl:
        try:
            httpsd = socketserver.TCPServer(("", https_port), NoCacheHandler)
            ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ssl_context.load_cert_chain(certfile=cert_path, keyfile=key_path)
            httpsd.socket = ssl_context.wrap_socket(httpsd.socket, server_side=True)
            t_https = threading.Thread(target=httpsd.serve_forever, daemon=True)
            t_https.start()
        except Exception as e:
            print(f"HTTPS setup warning: {e}")
            httpsd = None

    print("=" * 64)
    print("  演象·时空罗盘 (iOS PWA / Web 局域网真机调试服务器)")
    print("=" * 64)
    print(f" [HTTP 基础模式]  http://{local_ip}:{http_port}/")
    if httpsd:
        print(f" [HTTPS 安全模式] https://{local_ip}:{https_port}/  <-- 激活iPhone陀螺仪/相机推荐")
    print(f" 本机电脑访问:    http://localhost:{http_port}/")
    print("=" * 64)
    print(" 提示: iOS 13+ 苹果安全策略限制：")
    print(" 1. 使用 HTTPS 地址打开可直接解锁 iPhone 陀螺仪硬件随向转与真实 AR 相机；")
    print(" 2. 若使用 HTTP 地址，应用已内置【单指触控直接旋转盘面】，同样可流畅立向！")
    print(" 3. 在 Safari 点击「分享」->【添加到主屏幕】，即为独立全屏原生 App。")
    print("=" * 64)
    
    try:
        t_http.join()
    except KeyboardInterrupt:
        print("\n服务器已停止。")

if __name__ == "__main__":
    start_server()
