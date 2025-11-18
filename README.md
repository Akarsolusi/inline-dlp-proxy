# HTTPS DLP Proxy with Real-Time Monitoring

A comprehensive Data Loss Prevention (DLP) proxy system built on **mitmproxy** and **Envoy** with real-time monitoring, full HTTP/HTTPS traffic capture, and an interactive dashboard. This solution inspects all network traffic for sensitive data patterns including PII, credentials, API keys, financial data, and more.

## 🔑 Key Features

- **✅ Full HTTPS Inspection**: Decrypts and inspects HTTPS traffic using mitmproxy
- **✅ Real-Time DLP Detection**: Monitors both request and response traffic for 44+ sensitive data patterns
- **✅ Complete Traffic Capture**: Saves all HTTP requests and responses with unique flow IDs
- **✅ Interactive Dashboard**: Professional web UI with live alerts, statistics, and filtering
- **✅ Flow Viewer Tool**: Query and search captured traffic by URL, host, method, or status code
- **✅ Context-Aware Patterns**: Reduces false positives with intelligent pattern matching
- **✅ Destination Tracking**: See which domains/IPs are receiving sensitive data
- **✅ Severity Classification**: Critical, High, Medium, and Low severity levels
- **✅ Category Grouping**: PII, Credentials, Financial, Network, Telecom, etc.

## 📋 What's Detected

### Critical Severity
- South African ID Numbers
- SSN (Social Security Numbers)
- API Keys (Generic, AWS, GitHub, Google, Slack)
- Database Credentials & Connection Strings
- Private Keys (RSA, SSH, EC, DSA)
- AWS Access & Secret Keys
- Bank Account Numbers & IBAN
- Database Passwords

### High Severity
- Credit Card Numbers
- Bearer & JWT Tokens
- IMSI, MSISDN, IMEI (Telecom identifiers)
- Geo-Coordinates
- SWIFT Codes
- Password Fields
- Tax IDs

### Medium Severity
- Email Addresses
- Phone Numbers
- Physical Addresses
- Contract References
- Invoice Numbers
- Database Names
- Document File Transfers

### Low Severity
- IP Addresses

### File Transfer Detection
- ZIP, DEB, TAR, GZ archives
- Executable files (EXE, DLL, SO, BIN)
- Source code files (PY, JS, JAVA, GO, etc.)
- Document files (PDF, DOC, XLS, PPT)

## 🏗️ Architecture

```
Client Applications
       ↓
  mitmproxy:3128 (HTTPS Inspection)
       ↓
  DLP Python Script
       ↓
  [Alerts Log] + [HTTP Flows Log]
       ↓
  Frontend Dashboard:3000
```

**Traffic Flow:**
1. Client sends HTTPS request to mitmproxy (port 3128)
2. Mitmproxy decrypts HTTPS using custom CA certificate
3. DLP Python script inspects request/response bodies for sensitive patterns
4. Full HTTP flow (request + response) saved to `logs/http_flows.jsonl`
5. DLP alerts saved to `logs/dlp_alerts.log`
6. Frontend dashboard displays live alerts via Socket.IO

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.8+ (for flow viewer tool)
- Network connectivity to client applications

### Installation

```bash
# Clone or navigate to project directory
cd /path/to/envoy-dlp-proxy

# Start the services
docker-compose up -d

# Check status
docker-compose ps
```

### Access the Dashboard

Open in your browser:
```
http://localhost:3000
```

## 📊 Services and Ports

| Service | Port | Description |
|---------|------|-------------|
| Mitmproxy | 3128 | Main proxy with HTTPS inspection |
| Mitmweb UI | 8081 | Mitmproxy web interface |
| Frontend Dashboard | 3000 | Real-time DLP monitoring dashboard |
| Envoy Proxy | 8080 | Legacy Envoy proxy (optional) |
| Envoy Admin | 9901 | Envoy admin interface (optional) |

## 🔧 Configuration

### Configure Client to Use Proxy

**Environment variables:**
```bash
export HTTP_PROXY=http://proxy-server:3128
export HTTPS_PROXY=http://proxy-server:3128
export http_proxy=http://proxy-server:3128
export https_proxy=http://proxy-server:3128
```

**System-wide (APT/YUM):**
```bash
# For APT (Ubuntu/Debian)
echo 'Acquire::http::Proxy "http://proxy-server:3128";' | sudo tee /etc/apt/apt.conf.d/95proxies

# For YUM (RHEL/CentOS)
echo "proxy=http://proxy-server:3128" | sudo tee -a /etc/yum.conf
```

**Docker:**
```bash
# Create /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://proxy-server:3128"
Environment="HTTPS_PROXY=http://proxy-server:3128"
```

### Install CA Certificate (Required for HTTPS)

Mitmproxy generates a CA certificate automatically. Install it on client systems:

```bash
# Copy CA from mitmproxy volume
docker cp mitmproxy-dlp:/home/mitmproxy/.mitmproxy/mitmproxy-ca-cert.pem ./mitmproxy-ca.pem

# Install on Linux
sudo cp mitmproxy-ca.pem /usr/local/share/ca-certificates/mitmproxy-ca.crt
sudo update-ca-certificates

# Install on macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain mitmproxy-ca.pem
```

See [HTTPS-INSPECTION.md](HTTPS-INSPECTION.md) for detailed instructions.

## 🔍 Viewing Captured Traffic

### Using the Flow Viewer Tool

The system captures ALL HTTP/HTTPS traffic with unique flow IDs linking requests to responses.

**View recent flows:**
```bash
python3 scripts/flow_viewer.py --recent 10
```

**Search by URL:**
```bash
python3 scripts/flow_viewer.py --url "api.example.com" --detailed
```

**Search by host:**
```bash
python3 scripts/flow_viewer.py --host github.com --detailed
```

**Search by HTTP method:**
```bash
python3 scripts/flow_viewer.py --method POST
```

**Search by status code:**
```bash
python3 scripts/flow_viewer.py --status 404
```

**Get specific flow by ID:**
```bash
python3 scripts/flow_viewer.py --flow-id <uuid> --detailed
```

**View statistics:**
```bash
python3 scripts/flow_viewer.py --stats
```

See [FLOW_VIEWER_USAGE.md](FLOW_VIEWER_USAGE.md) for complete documentation.

### Using Mitmweb UI

Open `http://localhost:8081` and use filter expressions:

- `~s TEXT` - Search in request or response body
- `~d DOMAIN` - Filter by domain
- `~u URL` - Filter by URL pattern
- `~m METHOD` - Filter by HTTP method

Example: `~d github.com ~s token`

## 📈 Dashboard Features

The web dashboard at `http://localhost:3000` provides:

- **Live DLP Alerts**: Real-time stream of detected sensitive data
- **Statistics Cards**: Total, Critical, High, Medium, Low severity counts
- **Detection Patterns**: See which types of sensitive data are being detected
- **Destination Tracking**: View domains/IPs receiving sensitive data with category breakdowns
- **Interactive Filtering**: Filter alerts by severity, destination, or detection type
- **Alert Details Modal**: Click any alert for complete request/response information
- **Real-Time Updates**: Socket.IO powered live updates

## 📝 DLP Pattern Configuration

Patterns are defined in `rules/dlp_patterns.json`:

```json
{
  "patterns": [
    {
      "name": "Credit Card",
      "pattern": "\\b(?:\\d{4}[\\s-]?){3}\\d{4}\\b",
      "severity": "high",
      "category": "Financial"
    }
  ]
}
```

**After modifying patterns, restart mitmproxy:**
```bash
docker-compose restart mitmproxy
```

## 📂 Project Structure

```
envoy-dlp-proxy/
├── config/
│   └── envoy.yaml              # Envoy configuration (legacy)
├── certs/                      # SSL certificates (excluded from git)
│   └── README.md               # Certificate generation instructions
├── rules/
│   └── dlp_patterns.json       # DLP pattern definitions (44 patterns)
├── scripts/
│   ├── dlp_forward.py          # Main DLP inspection script for mitmproxy
│   ├── flow_viewer.py          # HTTP flow viewer tool
│   ├── manage-proxy.sh         # Proxy management
│   └── configure-client.sh     # Client configuration
├── frontend/
│   ├── server.js               # Node.js backend with Socket.IO
│   ├── Dockerfile
│   └── public/
│       ├── index.html          # Dashboard UI
│       ├── app.js              # Frontend JavaScript
│       └── styles.css          # Dashboard styles
├── logs/                       # Log files (excluded from git)
│   ├── dlp_alerts.log          # DLP detection alerts (JSON)
│   ├── http_flows.jsonl        # Complete HTTP request/response pairs
│   └── .gitkeep
├── docker-compose.yml          # Docker Compose configuration
├── .gitignore                  # Git ignore rules
├── README.md                   # This file
├── QUICKSTART.md               # Quick setup guide
├── HTTPS-INSPECTION.md         # HTTPS setup documentation
└── FLOW_VIEWER_USAGE.md        # Flow viewer documentation
```

## 📊 Log Files

### DLP Alerts (`logs/dlp_alerts.log`)

JSON-formatted log entries:
```json
{
  "timestamp": "2025-11-10T10:22:21.472895Z",
  "type": "Credit Card",
  "severity": "high",
  "direction": "request",
  "url": "https://api.example.com/payment",
  "host": "api.example.com",
  "method": "POST",
  "source_ip": "192.168.1.100",
  "matches_count": 1,
  "sample": "4532-1234-5678-9010"
}
```

### HTTP Flows (`logs/http_flows.jsonl`)

Complete request/response pairs with unique flow IDs:
```json
{
  "flow_id": "6c563b71-67c5-4e89-863d-d9214c2f98f9",
  "request": {
    "timestamp": "2025-11-10T10:22:21.472895Z",
    "client_ip": "172.18.0.1",
    "method": "POST",
    "url": "https://api.example.com/users",
    "headers": {...},
    "content": "request body",
    "content_length": 82
  },
  "response": {
    "timestamp": "2025-11-10T10:22:24.375242Z",
    "status_code": 200,
    "headers": {...},
    "content": "response body",
    "content_length": 621
  },
  "duration_ms": 2902.35
}
```

## 🔒 Security Considerations

1. **Sensitive Data in Logs**: DLP logs contain samples of detected data. Secure with proper file permissions:
   ```bash
   chmod 600 logs/dlp_alerts.log logs/http_flows.jsonl
   ```

2. **Certificate Security**: The CA private key allows decrypting all HTTPS traffic:
   - Keep `certs/ca.key` secure
   - Never commit certificates to git
   - Restrict access to certificate files
   - Rotate certificates regularly

3. **Log Retention**: Implement log rotation to prevent disk space issues:
   ```bash
   # logs/ directory is excluded from git
   # Implement logrotate for production
   ```

4. **Network Access**: Restrict proxy access with firewall rules:
   ```bash
   sudo ufw allow from 192.168.1.0/24 to any port 3128
   ```

5. **Dashboard Authentication**: Add authentication for production:
   - The dashboard currently has no authentication
   - Consider adding basic auth or OAuth

6. **Legal Compliance**: Ensure HTTPS interception complies with:
   - Local laws and regulations
   - Company policies
   - User consent requirements

## 🐛 Troubleshooting

### Proxy Not Starting

```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs mitmproxy
docker-compose logs frontend

# Restart services
docker-compose restart
```

### No Alerts Appearing

```bash
# Test with sample data
curl -x http://localhost:3128 -d "credit_card=4111-1111-1111-1111" http://httpbin.org/post

# Check if alerts are being logged
tail -f logs/dlp_alerts.log

# Verify mitmproxy is running
docker-compose logs mitmproxy | grep "DLP Inspector loaded"
```

### Certificate Errors on Clients

```bash
# Verify CA certificate is installed
ls /usr/local/share/ca-certificates/ | grep mitmproxy

# Update certificates
sudo update-ca-certificates

# Test connection
curl -v --proxy http://proxy-server:3128 https://www.google.com
```

### Dashboard Not Loading

```bash
# Check frontend status
docker-compose logs frontend

# Verify logs directory permissions
ls -la logs/

# Restart frontend
docker-compose restart frontend
```

## 🎯 Use Cases

1. **Security Monitoring**: Detect data leakage and policy violations
2. **Compliance**: Monitor for PII, PCI, HIPAA data exposure
3. **Incident Response**: Investigate security incidents with full traffic logs
4. **Development Testing**: Test applications for sensitive data leaks
5. **API Security**: Monitor API traffic for credentials and keys

## 📚 Documentation

- **[README.md](README.md)** - This file, complete overview
- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[HTTPS-INSPECTION.md](HTTPS-INSPECTION.md)** - HTTPS inspection setup
- **[FLOW_VIEWER_USAGE.md](FLOW_VIEWER_USAGE.md)** - Flow viewer tool guide
- **[certs/README.md](certs/README.md)** - Certificate management

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

## 📜 License

MIT License - See LICENSE file for details

## 🙏 Acknowledgments

- Built on **mitmproxy** for HTTPS interception
- **Envoy Proxy** for advanced routing (optional)
- **Socket.IO** for real-time dashboard updates
- **Express.js** for backend API
- **Python 3** for DLP inspection logic

---

**🚀 Ready to get started?**

1. Clone the repository
2. Run `docker-compose up -d`
3. Open `http://localhost:3000`
4. Configure clients to use proxy at port 3128
5. Install CA certificate on clients
6. Watch the alerts roll in!

**Need help?** Check the troubleshooting section or open an issue.
