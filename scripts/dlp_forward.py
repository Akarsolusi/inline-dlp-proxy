"""
mitmproxy addon to perform DLP inspection on decrypted HTTPS traffic
"""
import json
import re
import uuid
from mitmproxy import http, ctx
from datetime import datetime
from pathlib import Path


class DLPInspector:
    def __init__(self):
        self.patterns = []
        self.log_file = "/logs/dlp_alerts.log"
        self.flows_file = "/logs/http_flows.jsonl"
        self.flows = {}  # Store flows temporarily until response arrives

    def load(self, loader):
        """Called when the addon is loaded"""
        self.patterns = self.load_patterns()
        ctx.log.info(f"DLP Inspector loaded with {len(self.patterns)} patterns")

    def load_patterns(self):
        """Load DLP patterns from the rules file"""
        try:
            with open('/scripts/../rules/dlp_patterns.json', 'r') as f:
                data = json.load(f)
                patterns = data.get('patterns', [])
                ctx.log.info(f"Loaded {len(patterns)} DLP patterns")
                return patterns
        except Exception as e:
            ctx.log.error(f"Failed to load DLP patterns: {e}")
            return []

    def log_alert(self, alert_data):
        """Write DLP alert to log file"""
        try:
            with open(self.log_file, 'a') as f:
                f.write(json.dumps(alert_data) + '\n')
        except Exception as e:
            ctx.log.error(f"Failed to write alert to log: {e}")

    def save_flow(self, flow_data):
        """Save complete HTTP flow (request + response) to file"""
        try:
            with open(self.flows_file, 'a') as f:
                f.write(json.dumps(flow_data) + '\n')
        except Exception as e:
            ctx.log.error(f"Failed to write flow to log: {e}")

    def inspect_content(self, content: bytes, flow: http.HTTPFlow, direction: str):
        """Inspect content for sensitive data patterns"""
        if not content:
            return

        try:
            text = content.decode('utf-8', errors='ignore')
        except Exception as e:
            return

        for pattern in self.patterns:
            regex = pattern.get('pattern', '')
            name = pattern.get('name', 'Unknown')
            severity = pattern.get('severity', 'medium')

            try:
                matches = re.findall(regex, text, re.IGNORECASE)
                if matches:
                    # Get client IP
                    client_ip = 'unknown'
                    if flow.client_conn and flow.client_conn.peername:
                        client_ip = flow.client_conn.peername[0]

                    alert = {
                        'timestamp': datetime.utcnow().isoformat() + 'Z',
                        'type': name,
                        'severity': severity,
                        'direction': direction,
                        'url': flow.request.pretty_url,
                        'host': flow.request.host,
                        'method': flow.request.method,
                        'source_ip': client_ip,
                        'matches_count': len(matches),
                        'sample': str(matches[0])[:100] if matches else ''
                    }

                    # Log to console
                    ctx.log.warn(f"DLP ALERT [{severity.upper()}]: {name} detected in {direction} to {flow.request.host}")

                    # Log to file
                    self.log_alert(alert)

            except re.error as e:
                ctx.log.error(f"Invalid regex pattern {name}: {e}")

    def request(self, flow: http.HTTPFlow):
        """Capture and inspect outgoing requests"""
        # Generate unique flow ID
        flow_id = str(uuid.uuid4())
        flow.metadata['flow_id'] = flow_id
        flow.metadata['request_timestamp'] = datetime.utcnow().isoformat() + 'Z'

        # Get client IP
        client_ip = 'unknown'
        if flow.client_conn and flow.client_conn.peername:
            client_ip = flow.client_conn.peername[0]

        # Capture request data
        request_data = {
            'flow_id': flow_id,
            'timestamp': flow.metadata['request_timestamp'],
            'client_ip': client_ip,
            'method': flow.request.method,
            'url': flow.request.pretty_url,
            'host': flow.request.host,
            'port': flow.request.port,
            'scheme': flow.request.scheme,
            'path': flow.request.path,
            'headers': dict(flow.request.headers),
            'content': flow.request.content.decode('utf-8', errors='ignore') if flow.request.content else '',
            'content_length': len(flow.request.content) if flow.request.content else 0
        }

        # Store temporarily until response arrives
        self.flows[flow_id] = request_data

        # Inspect request for DLP
        if flow.request.content:
            self.inspect_content(flow.request.content, flow, "request")

    def response(self, flow: http.HTTPFlow):
        """Capture and inspect incoming responses"""
        # Get flow ID from request
        flow_id = flow.metadata.get('flow_id')
        if not flow_id:
            return

        # Get request data
        request_data = self.flows.get(flow_id)
        if not request_data:
            return

        response_timestamp = datetime.utcnow().isoformat() + 'Z'

        # Capture response data
        response_data = {
            'timestamp': response_timestamp,
            'status_code': flow.response.status_code if flow.response else 0,
            'reason': flow.response.reason if flow.response else '',
            'headers': dict(flow.response.headers) if flow.response else {},
            'content': flow.response.content.decode('utf-8', errors='ignore') if flow.response and flow.response.content else '',
            'content_length': len(flow.response.content) if flow.response and flow.response.content else 0
        }

        # Combine request and response
        complete_flow = {
            'flow_id': flow_id,
            'request': request_data,
            'response': response_data,
            'duration_ms': self._calculate_duration(request_data['timestamp'], response_timestamp)
        }

        # Save complete flow
        self.save_flow(complete_flow)

        # Clean up temporary storage
        del self.flows[flow_id]

        # Inspect response for DLP
        if flow.response and flow.response.content:
            self.inspect_content(flow.response.content, flow, "response")

    def _calculate_duration(self, start_time, end_time):
        """Calculate duration in milliseconds between two ISO timestamps"""
        try:
            start = datetime.fromisoformat(start_time.replace('Z', '+00:00'))
            end = datetime.fromisoformat(end_time.replace('Z', '+00:00'))
            duration = (end - start).total_seconds() * 1000
            return round(duration, 2)
        except:
            return 0


addons = [DLPInspector()]
