#!/usr/bin/env python3
"""
Guardian Demo Application
A simple web server for container security demonstrations
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os
import sys
from datetime import datetime

class GuardianHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()

            response = {
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'guardian': 'Star-Lord',
                'message': 'Policy enforcement active',
                'security': {
                    'user_id': os.getuid(),
                    'is_root': os.getuid() == 0,
                    'python_version': sys.version
                }
            }

            self.wfile.write(json.dumps(response, indent=2).encode())

        elif self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()

            html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Guardian Demo - Container Security</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; background: #1a1a2e; color: #eee; }
                    .container { max-width: 800px; margin: 0 auto; }
                    .header { text-align: center; margin-bottom: 40px; }
                    .status { background: #16213e; padding: 20px; border-radius: 8px; margin: 20px 0; }
                    .guardian { color: #0f4c75; font-weight: bold; }
                    .secure { color: #4ade80; }
                    .warning { color: #fbbf24; }
                    .danger { color: #ef4444; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🚀 Guardians of the Container Galaxy</h1>
                        <h2>Security Policy Demo Application</h2>
                    </div>

                    <div class="status">
                        <h3>Container Security Status</h3>
                        <p><strong>Guardian:</strong> <span class="guardian">Star-Lord (Policy Orchestration)</span></p>
                        <p><strong>User ID:</strong> <span class="{user_class}">{user_id}</span></p>
                        <p><strong>Root Access:</strong> <span class="{root_class}">{root_status}</span></p>
                        <p><strong>Timestamp:</strong> {timestamp}</p>
                    </div>

                    <div class="status">
                        <h3>Security Principles</h3>
                        <ul>
                            <li>✅ Non-root container execution</li>
                            <li>✅ Signed image verification</li>
                            <li>✅ Admission policy enforcement</li>
                            <li>✅ Runtime security monitoring</li>
                        </ul>
                    </div>

                    <div class="status">
                        <h3>API Endpoints</h3>
                        <p><strong>Health Check:</strong> <a href="/health">/health</a></p>
                        <p><strong>Home:</strong> <a href="/">/</a></p>
                    </div>
                </div>
            </body>
            </html>
            """.format(
                user_id=os.getuid(),
                root_status="ENABLED (INSECURE)" if os.getuid() == 0 else "DISABLED (SECURE)",
                root_class="danger" if os.getuid() == 0 else "secure",
                user_class="danger" if os.getuid() == 0 else "secure",
                timestamp=datetime.now().isoformat()
            )

            self.wfile.write(html.encode())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

def main():
    port = int(os.environ.get('PORT', 8080))
    server = HTTPServer(('0.0.0.0', port), GuardianHandler)

    print(f"🚀 Guardian Demo Server starting on port {port}")
    print(f"👤 Running as user ID: {os.getuid()}")
    print(f"🔒 Root access: {'ENABLED (INSECURE)' if os.getuid() == 0 else 'DISABLED (SECURE)'}")
    print(f"🌐 Health endpoint: http://localhost:{port}/health")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Guardian Demo Server stopped")
        server.server_close()

if __name__ == '__main__':
    main()