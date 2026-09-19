import http.server
import socketserver
import os
import sys

PORT = 8060
DIRECTORY = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "builds", "web"))

class GodotHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

def run_server():
    print(f"Servidor Godot Web iniciado en http://localhost:{PORT}")
    print(f"Sirviendo archivos desde: {DIRECTORY}")
    # Allow address reuse to prevent port busy issues on restarts
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), GodotHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServidor detenido.")

if __name__ == '__main__':
    run_server()
