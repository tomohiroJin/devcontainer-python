"""HTTP server for scripts/check_devcontainer.sh: every request gets a 401.

Used to check that `make doctor` leaves the credential helpers alone when a
server refuses a credential. Usage: python scripts/http_401_server.py PORT
"""

import http.server
import sys


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="test"')
        self.end_headers()

    do_POST = do_GET

    def log_message(self, format: str, *args: object) -> None:
        return


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
