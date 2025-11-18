#!/usr/bin/env python3
"""
Tool to view and search HTTP flows captured by mitmproxy
"""
import json
import sys
import argparse
from datetime import datetime
from pathlib import Path


class FlowViewer:
    def __init__(self, flows_file='/home/ubradar-systems/scripts/envoy-dlp-proxy/logs/http_flows.jsonl'):
        self.flows_file = flows_file

    def load_flows(self):
        """Load all flows from file"""
        flows = []
        try:
            with open(self.flows_file, 'r') as f:
                for line in f:
                    if line.strip():
                        flows.append(json.loads(line))
        except FileNotFoundError:
            print(f"Error: Flows file not found: {self.flows_file}")
            return []
        except Exception as e:
            print(f"Error loading flows: {e}")
            return []
        return flows

    def search_by_url(self, url_pattern):
        """Search flows by URL pattern"""
        flows = self.load_flows()
        matches = [f for f in flows if url_pattern.lower() in f['request']['url'].lower()]
        return matches

    def search_by_host(self, host):
        """Search flows by host"""
        flows = self.load_flows()
        matches = [f for f in flows if host.lower() in f['request']['host'].lower()]
        return matches

    def search_by_method(self, method):
        """Search flows by HTTP method"""
        flows = self.load_flows()
        matches = [f for f in flows if f['request']['method'].upper() == method.upper()]
        return matches

    def search_by_status(self, status_code):
        """Search flows by response status code"""
        flows = self.load_flows()
        matches = [f for f in flows if f['response']['status_code'] == status_code]
        return matches

    def get_by_flow_id(self, flow_id):
        """Get a specific flow by ID"""
        flows = self.load_flows()
        for flow in flows:
            if flow['flow_id'] == flow_id:
                return flow
        return None

    def list_recent(self, count=10):
        """List most recent flows"""
        flows = self.load_flows()
        return flows[-count:] if len(flows) > count else flows

    def display_flow_summary(self, flow):
        """Display a summary of a flow"""
        req = flow['request']
        resp = flow['response']
        print(f"\n{'='*80}")
        print(f"Flow ID: {flow['flow_id']}")
        print(f"Time: {req['timestamp']}")
        print(f"Duration: {flow['duration_ms']}ms")
        print(f"\nREQUEST:")
        print(f"  {req['method']} {req['url']}")
        print(f"  Client IP: {req['client_ip']}")
        print(f"  Content Length: {req['content_length']} bytes")
        print(f"\nRESPONSE:")
        print(f"  Status: {resp['status_code']} {resp['reason']}")
        print(f"  Content Length: {resp['content_length']} bytes")

    def display_flow_detailed(self, flow):
        """Display detailed flow information"""
        req = flow['request']
        resp = flow['response']

        print(f"\n{'='*80}")
        print(f"FLOW ID: {flow['flow_id']}")
        print(f"{'='*80}")

        print(f"\n[REQUEST] {req['timestamp']}")
        print(f"{req['method']} {req['url']}")
        print(f"Client IP: {req['client_ip']}")
        print(f"\nRequest Headers:")
        for key, value in req['headers'].items():
            print(f"  {key}: {value}")

        if req['content']:
            print(f"\nRequest Body ({req['content_length']} bytes):")
            print(self._format_content(req['content'], req['headers'].get('content-type', '')))

        print(f"\n[RESPONSE] {resp['timestamp']} (after {flow['duration_ms']}ms)")
        print(f"Status: {resp['status_code']} {resp['reason']}")
        print(f"\nResponse Headers:")
        for key, value in resp['headers'].items():
            print(f"  {key}: {value}")

        if resp['content']:
            print(f"\nResponse Body ({resp['content_length']} bytes):")
            print(self._format_content(resp['content'], resp['headers'].get('content-type', '')))

        print(f"\n{'='*80}\n")

    def _format_content(self, content, content_type):
        """Format content based on content type"""
        # Limit content display
        max_length = 2000
        if len(content) > max_length:
            content = content[:max_length] + f"\n... (truncated, {len(content)} total bytes)"

        # Try to pretty print JSON
        if 'json' in content_type.lower():
            try:
                obj = json.loads(content)
                return json.dumps(obj, indent=2)
            except:
                pass

        return content

    def stats(self):
        """Display statistics about flows"""
        flows = self.load_flows()
        if not flows:
            print("No flows found")
            return

        total = len(flows)
        methods = {}
        hosts = {}
        status_codes = {}

        for flow in flows:
            method = flow['request']['method']
            host = flow['request']['host']
            status = flow['response']['status_code']

            methods[method] = methods.get(method, 0) + 1
            hosts[host] = hosts.get(host, 0) + 1
            status_codes[status] = status_codes.get(status, 0) + 1

        print(f"\n{'='*60}")
        print(f"HTTP FLOWS STATISTICS")
        print(f"{'='*60}")
        print(f"\nTotal Flows: {total}")

        print(f"\nTop Methods:")
        for method, count in sorted(methods.items(), key=lambda x: x[1], reverse=True):
            print(f"  {method}: {count}")

        print(f"\nTop Hosts:")
        for host, count in sorted(hosts.items(), key=lambda x: x[1], reverse=True)[:10]:
            print(f"  {host}: {count}")

        print(f"\nStatus Codes:")
        for status, count in sorted(status_codes.items()):
            print(f"  {status}: {count}")

        print(f"\n{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(description='View and search HTTP flows')
    parser.add_argument('--file', default='/home/ubradar-systems/scripts/envoy-dlp-proxy/logs/http_flows.jsonl',
                        help='Path to flows file')
    parser.add_argument('--url', help='Search by URL pattern')
    parser.add_argument('--host', help='Search by host')
    parser.add_argument('--method', help='Search by HTTP method')
    parser.add_argument('--status', type=int, help='Search by status code')
    parser.add_argument('--flow-id', help='Get specific flow by ID')
    parser.add_argument('--recent', type=int, metavar='N', help='Show N most recent flows')
    parser.add_argument('--stats', action='store_true', help='Show statistics')
    parser.add_argument('--detailed', action='store_true', help='Show detailed view (includes headers and body)')

    args = parser.parse_args()

    viewer = FlowViewer(args.file)
    flows = []

    if args.stats:
        viewer.stats()
        return

    if args.flow_id:
        flow = viewer.get_by_flow_id(args.flow_id)
        if flow:
            flows = [flow]
        else:
            print(f"Flow not found: {args.flow_id}")
            return
    elif args.url:
        flows = viewer.search_by_url(args.url)
    elif args.host:
        flows = viewer.search_by_host(args.host)
    elif args.method:
        flows = viewer.search_by_method(args.method)
    elif args.status:
        flows = viewer.search_by_status(args.status)
    elif args.recent:
        flows = viewer.list_recent(args.recent)
    else:
        flows = viewer.list_recent(10)

    if not flows:
        print("No flows found")
        return

    print(f"\nFound {len(flows)} flow(s)")

    for flow in flows:
        if args.detailed:
            viewer.display_flow_detailed(flow)
        else:
            viewer.display_flow_summary(flow)


if __name__ == '__main__':
    main()
