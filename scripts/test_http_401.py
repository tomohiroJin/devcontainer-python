"""HTTP server for scripts/check_devcontainer.sh: every request gets a 401.

Used to check that `make doctor` leaves the credential helpers alone when a
server refuses a credential. Usage: python scripts/test_http_401.py PORT
"""

import http.server
import sys


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802 (name fixed by http.server)
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="test"')
        self.end_headers()

    do_POST = do_GET  # noqa: N815

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        return


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
