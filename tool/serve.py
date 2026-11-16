#!/usr/bin/env python3
"""Serves build/web locally the way Cloudflare does in production: the headers
in build/web/_headers on every response, and clean addresses (/faq serves
faq.html), so the service worker and cross-origin isolation can be tested.

Usage: python3 tool/serve.py [port]   (default 8871)
"""
import functools
import http.server
import sys
from pathlib import Path

WEB = Path(__file__).resolve().parent.parent / 'build' / 'web'


def headers():
    """The `/*` block of build/web/_headers, as (name, value) pairs."""
    found, block = [], False
    path = WEB / '_headers'
    for line in path.read_text().splitlines() if path.exists() else []:
        if not line.strip():
            continue
        if not line[0].isspace():
            block = line.strip() == '/*'
        elif block and ':' in line:
            name, _, value = line.strip().partition(':')
            found.append((name.strip(), value.strip()))
    return found


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.mjs': 'text/javascript'}

    def translate_path(self, path):
        found = super().translate_path(path)
        if not Path(found).exists() and Path(found + '.html').is_file():
            return found + '.html'
        return found

    def end_headers(self):
        for name, value in headers():
            self.send_header(name, value)
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8871
    server = http.server.ThreadingHTTPServer(('127.0.0.1', port), functools.partial(Handler, directory=str(WEB)))
    print(f'Serving {WEB} at http://localhost:{port}/')
    server.serve_forever()
