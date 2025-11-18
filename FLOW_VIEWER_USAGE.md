# HTTP Flow Viewer - Usage Guide

The DLP proxy now captures all HTTP requests and responses, saving them to `/logs/http_flows.jsonl` with unique flow IDs that link requests to their responses.

## Flow Viewer Tool

Located at: `scripts/flow_viewer.py`

## Usage Examples

### View Recent Flows

```bash
# View 10 most recent flows (default)
python3 scripts/flow_viewer.py

# View 5 most recent flows
python3 scripts/flow_viewer.py --recent 5

# View with full details (headers and body)
python3 scripts/flow_viewer.py --recent 5 --detailed
```

### Search by URL Pattern

```bash
# Search for flows containing "httpbin.org" in URL
python3 scripts/flow_viewer.py --url httpbin.org

# Search for POST endpoint
python3 scripts/flow_viewer.py --url "/post" --detailed
```

### Search by Host

```bash
# Find all flows to a specific host
python3 scripts/flow_viewer.py --host example.com

# With detailed view
python3 scripts/flow_viewer.py --host httpbin.org --detailed
```

### Search by HTTP Method

```bash
# Find all POST requests
python3 scripts/flow_viewer.py --method POST

# Find all GET requests
python3 scripts/flow_viewer.py --method GET --detailed
```

### Search by Status Code

```bash
# Find all failed requests (404)
python3 scripts/flow_viewer.py --status 404

# Find server errors (500)
python3 scripts/flow_viewer.py --status 500 --detailed
```

### Get Specific Flow by ID

```bash
# View a specific flow by its UUID
python3 scripts/flow_viewer.py --flow-id 6c563b71-67c5-4e89-863d-d9214c2f98f9 --detailed
```

### View Statistics

```bash
# Show statistics about all captured flows
python3 scripts/flow_viewer.py --stats
```

Output shows:
- Total number of flows
- HTTP methods distribution
- Top destination hosts
- Status code distribution

## Flow Data Structure

Each flow contains:

### Request Data
- `flow_id`: Unique identifier linking request to response
- `timestamp`: ISO timestamp of request
- `client_ip`: Source IP address
- `method`: HTTP method (GET, POST, etc.)
- `url`: Full URL including query parameters
- `host`: Destination hostname
- `port`: Destination port
- `scheme`: http or https
- `path`: URL path
- `headers`: All request headers
- `content`: Request body (decoded)
- `content_length`: Size of request body in bytes

### Response Data
- `timestamp`: ISO timestamp of response
- `status_code`: HTTP status code (200, 404, 500, etc.)
- `reason`: Status reason phrase (OK, Not Found, etc.)
- `headers`: All response headers
- `content`: Response body (decoded, pretty-printed JSON if applicable)
- `content_length`: Size of response body in bytes

### Flow Metadata
- `duration_ms`: Time between request and response in milliseconds

## Output Modes

### Summary View (default)
Shows basic information:
- Flow ID
- Request timestamp
- Duration
- Request method and URL
- Client IP
- Response status

### Detailed View (`--detailed`)
Shows complete information:
- All request headers
- Full request body
- All response headers
- Full response body (with JSON pretty-printing)
- Automatic truncation for large bodies (> 2000 chars)

## Tips

1. **Pipe to grep for advanced filtering:**
   ```bash
   python3 scripts/flow_viewer.py --recent 100 | grep -A 10 "credit_card"
   ```

2. **Export specific flow to file:**
   ```bash
   python3 scripts/flow_viewer.py --flow-id <ID> --detailed > flow_details.txt
   ```

3. **Monitor flows in real-time:**
   ```bash
   watch -n 2 'python3 scripts/flow_viewer.py --recent 5'
   ```

4. **Find flows with sensitive data:**
   ```bash
   python3 scripts/flow_viewer.py --recent 50 --detailed | grep -i "password\|credit_card\|api_key"
   ```

5. **Check specific host traffic:**
   ```bash
   python3 scripts/flow_viewer.py --host example.com --detailed
   ```

## File Location

Flows are stored in: `/home/ubradar-systems/scripts/envoy-dlp-proxy/logs/http_flows.jsonl`

Each line is a complete JSON object representing one HTTP flow (request + response pair).

## Integration with DLP Alerts

When a DLP alert is triggered:
1. Check the DLP alerts log: `/logs/dlp_alerts.log`
2. Note the host, URL, and timestamp
3. Use the flow viewer to get the complete request/response:
   ```bash
   python3 scripts/flow_viewer.py --host <host> --detailed
   ```

This allows you to see the full context of sensitive data that was detected.
