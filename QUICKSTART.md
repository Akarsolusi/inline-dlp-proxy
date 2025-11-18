# Quick Start Guide

Get your Envoy DLP Proxy with HTTPS inspection up and running in 5 minutes!

## Step 1: Prepare the System

```bash
# Navigate to project directory
cd /home/ubradar-systems/scripts/envoy-dlp-proxy

# Make scripts executable
chmod +x scripts/*.sh

# Create logs directory
mkdir -p logs
```

## Step 2: Generate CA Certificate (for HTTPS Inspection)

```bash
./scripts/generate-ca.sh
```

This creates the certificate authority needed to intercept HTTPS traffic. **Keep `certs/ca.key` secure!**

## Step 3: Start the Proxy

**Option A: Using the management script**
```bash
./scripts/manage-proxy.sh start
```

**Option B: Using Docker Compose directly**
```bash
docker-compose up -d
```

**Option C: Install as a systemd service** (recommended for production)
```bash
sudo ./scripts/manage-proxy.sh install
sudo systemctl start envoy-dlp
sudo systemctl enable envoy-dlp  # Enable on boot
```

## Step 4: Verify It's Running

```bash
# Check service status
./scripts/manage-proxy.sh status

# Test the proxy
curl -x http://localhost:8080 http://www.google.com

# Check admin interface
curl http://localhost:9901/stats
```

## Step 5: Access the Dashboard

Open your browser and navigate to:
```
http://localhost:3000
```

You should see the DLP monitoring dashboard with statistics and alerts.

## Step 6: Configure Client Servers (with HTTPS Inspection)

On each server you want to monitor:

**Step 6a: Install CA Certificate**
```bash
# Copy CA from proxy server
scp user@proxy-server:/path/to/envoy-dlp-proxy/certs/ca.crt /tmp/
scp user@proxy-server:/path/to/envoy-dlp-proxy/scripts/install-ca.sh /tmp/

# Install CA certificate
sudo /tmp/install-ca.sh /tmp/ca.crt
```

**Step 6b: Configure Proxy**
```bash
# Copy configuration script
scp user@proxy-server:/path/to/envoy-dlp-proxy/scripts/configure-client.sh /tmp/

# Configure to use proxy (port 3128 for HTTPS inspection)
sudo /tmp/configure-client.sh configure YOUR_PROXY_IP 3128
```

Replace `YOUR_PROXY_IP` with the IP address of your proxy server.

## Step 7: Test DLP Detection

From a client server (or locally), make a request with sensitive data:

```bash
# Test with email detection
curl -x http://YOUR_PROXY_IP:8080 \
  -H "X-Test-Email: user@example.com" \
  http://httpbin.org/headers

# Test with credit card pattern
curl -x http://YOUR_PROXY_IP:8080 \
  -d "card=4532-1234-5678-9876" \
  http://httpbin.org/post

# Test with API key pattern
curl -x http://YOUR_PROXY_IP:8080 \
  -H "API-Key: AKIA1234567890ABCDEF" \
  http://httpbin.org/headers
```

## Step 7: Monitor Alerts

**Watch alerts in real-time:**
```bash
./scripts/manage-proxy.sh alerts
```

**View the dashboard:**
Go to `http://YOUR_PROXY_IP:3000` in your browser

**Check log files:**
```bash
# DLP alerts (JSON format)
tail -f logs/dlp_alerts.log

# Access logs
tail -f logs/access.log
```

## Common Commands

| Command | Description |
|---------|-------------|
| `./scripts/manage-proxy.sh start` | Start the proxy |
| `./scripts/manage-proxy.sh stop` | Stop the proxy |
| `./scripts/manage-proxy.sh restart` | Restart the proxy |
| `./scripts/manage-proxy.sh status` | Check status |
| `./scripts/manage-proxy.sh logs` | View proxy logs |
| `./scripts/manage-proxy.sh alerts` | View DLP alerts |

## Stopping the Proxy

**Stop everything (recommended):**
```bash
./scripts/stop-all.sh
```
This stops the proxy and shows instructions for disabling it on client servers.

**Stop server only:**
```bash
./scripts/manage-proxy.sh stop
```

**Remove client proxy configuration:**
```bash
# On each client server
sudo /tmp/configure-client.sh remove
```

## Troubleshooting

**Proxy won't start:**
```bash
# Check if ports are in use
sudo netstat -tulpn | grep -E ':(8080|8443|9901|3000)'

# Check Docker logs
docker-compose logs
```

**Dashboard not accessible:**
```bash
# Check if frontend container is running
docker-compose ps

# View frontend logs
docker-compose logs frontend
```

**No alerts appearing:**
```bash
# Verify logs directory exists and is writable
ls -la logs/

# Test with sample data
curl -x http://localhost:8080 -d "email=test@test.com" http://httpbin.org/post

# Check if alert was logged
cat logs/dlp_alerts.log
```

## Next Steps

1. **Customize DLP rules**: Edit `lua/dlp_filter.lua` to add your own patterns
2. **Set up log rotation**: Configure logrotate for the log files
3. **Secure the dashboard**: Add authentication (see README.md)
4. **Configure firewall**: Restrict access to proxy ports
5. **Set up monitoring**: Monitor the proxy health and performance

## Important Notes

- The proxy is transparent to applications - they just need to be configured to use it
- **HTTPS inspection is enabled** when using port 3128 with CA certificate installed
- DLP alerts are stored in JSON format in `logs/dlp_alerts.log`
- The dashboard updates in real-time using WebSockets
- You can start/stop the proxy anytime without affecting client configurations
- Protect the CA private key (`certs/ca.key`) - it can decrypt all HTTPS traffic!

## More Information

- **[README.md](README.md)** - Complete documentation
- **[HTTPS-INSPECTION.md](HTTPS-INSPECTION.md)** - Detailed HTTPS inspection guide
