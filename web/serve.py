#!/usr/bin/env python3
"""Simple HTTP server with COOP/COEP headers for SharedArrayBuffer support."""
import http.server
import os

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def log_message(self, format, *args):
        pass  # silence request logs

os.chdir(os.path.dirname(os.path.abspath(__file__)))
httpd = http.server.HTTPServer(("", 8765), Handler)
print("Serving at http://localhost:8765")
httpd.serve_forever()
