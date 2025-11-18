# HTTPS Inspection Guide

This guide explains how to enable full HTTPS inspection (SSL/TLS termination) for the DLP proxy.

## Overview

The solution uses **Squid Proxy with SSL Bump** to decrypt, inspect, and re-encrypt HTTPS traffic. This allows the DLP filter to see the contents of HTTPS requests and responses.

## Architecture with HTTPS Inspection

```
Client → [HTTPS Encrypted] → Squid (SSL Bump) → [Decrypted HTTP] → Envoy + DLP Filter → [Re-encrypted] → Internet
                                    ↓                                        ↓
                            Generates fake cert                    Buffers & inspects
                            signed by your CA                      with Lua DLP filter
```

##How It Works

1. **Client initiates HTTPS request** (e.g., `curl https://api.example.com`)
2. **Squid intercepts the CONNECT request**
3. **Squid generates a fake certificate** for api.example.com (signed by your CA)
4. **Client validates the certificate** (trusts it because your CA is installed)
5. **TLS connection established** between client and Squid
6. **Squid decrypts the traffic** and forwards to Envoy
7. **Envoy DLP filter inspects** the plain-text content
8. **Squid re-encrypts** and forwards to the real destination
9. **Response follows the same path** in reverse

## Setup Instructions

### Step 1: Generate CA Certificate

On the proxy server, generate the root CA certificate:

```bash
cd /home/ubradar-systems/scripts/envoy-dlp-proxy
chmod +x scripts/generate-ca.sh
./scripts/generate-ca.sh
```

This creates:
- `certs/ca.pem` - CA certificate (PEM format)
- `certs/ca.crt` - CA certificate (DER format for easy installation)
- `certs/ca.key` - CA private key (**KEEP SECURE!**)

### Step 2: Start the Proxy with HTTPS Inspection

```bash
./scripts/manage-proxy.sh start
```

This starts three containers:
1. **Squid** - SSL bump proxy (port 3128) - decrypts HTTPS and forwards to Envoy
2. **Envoy** - DLP inspection with buffering (port 8080) - inspects decrypted traffic
3. **Frontend** - Dashboard (port 3000) - displays DLP alerts and traffic

### Step 3: Install CA on Client Servers

On each client server you want to monitor:

**Option A: Copy CA file manually**
```bash
# From proxy server
scp /home/ubradar-systems/scripts/envoy-dlp-proxy/certs/ca.crt user@client-server:/tmp/

# On client server
sudo scripts/install-ca.sh /tmp/ca.crt
```

**Option B: Download from dashboard**
```bash
# On client server
curl http://PROXY_IP:3000/ca.crt -o /tmp/ca.crt
sudo scripts/install-ca.sh /tmp/ca.crt
```

### Step 4: Configure Client to Use Proxy

On the client server:

```bash
sudo ./configure-client.sh configure PROXY_IP 3128
```

### Step 5: Test HTTPS Inspection

On the client server, test with a simple HTTPS request:

```bash
# This should work and be inspected
curl -v https://www.google.com

# Check if it passed through proxy
curl -v https://httpbin.org/get
```

Check the dashboard at `http://PROXY_IP:3000` - you should see any sensitive data detected in the HTTPS traffic.

## Testing DLP Detection with HTTPS

### Test 1: API Key in HTTPS Header

```bash
curl -H "Authorization: Bearer AKIA1234567890ABCDEF" https://httpbin.org/headers
```

Expected: Alert for "AWS Access Key" in dashboard

### Test 2: Credit Card in HTTPS POST

```bash
curl -X POST https://httpbin.org/post \
  -H "Content-Type: application/json" \
  -d '{"card":"4532-1234-5678-9876","name":"John Doe"}'
```

Expected: Alert for "Credit Card" in dashboard

### Test 3: Email in HTTPS Query

```bash
curl "https://httpbin.org/get?email=sensitive@company.com"
```

Expected: Alert for "Email" in dashboard

## Ports Reference

| Service | Port | Purpose |
|---------|------|---------|
| Squid Proxy | 3128 | Main proxy endpoint (HTTP + HTTPS with SSL bump) |
| Envoy Proxy | 8080 | DLP inspection (receives decrypted traffic from Squid) |
| Envoy Admin | 9901 | Envoy admin interface |
| Frontend | 3000 | Web dashboard |

## Security Considerations

### Critical Security Points

1. **CA Private Key Protection**
   - The `certs/ca.key` file is extremely sensitive
   - Anyone with this key can intercept HTTPS traffic
   - Store backups in a secure, encrypted location
   - Consider using hardware security modules (HSM) for production

2. **Proxy Server Security**
   - The proxy server can see ALL HTTPS traffic
   - Harden the OS and limit access
   - Enable disk encryption
   - Monitor access logs
   - Use firewalls to restrict who can connect

3. **Certificate Pinning**
   - Some applications (banking apps, security tools) use certificate pinning
   - These apps will FAIL with the proxy because they expect specific certificates
   - This is a security feature - don't try to bypass it

4. **Compliance**
   - Check your organization's policies on HTTPS inspection
   - Some regulations prohibit or restrict SSL interception
   - Get proper authorization before deploying

5. **User Privacy**
   - Inform users that traffic is being monitored
   - Comply with privacy laws (GDPR, CCPA, etc.)
   - Consider not inspecting certain domains (banking, healthcare)

### Limiting Inspection Scope

You can configure Squid to NOT inspect certain domains. Edit `config/squid.conf`:

```conf
# Add these lines to skip inspection for certain domains
acl no_bump_domains dstdomain .bank.com .healthcare.org
ssl_bump splice no_bump_domains
ssl_bump peek step1
ssl_bump bump all
```

## Troubleshooting

### Client Gets Certificate Errors

**Symptom:** `SSL certificate problem: unable to get local issuer certificate`

**Solution:**
1. Verify CA is installed: `ls /usr/local/share/ca-certificates/`
2. Update certificates: `sudo update-ca-certificates`
3. Test: `curl -v https://www.google.com`

### Squid Not Starting

**Check logs:**
```bash
docker-compose logs squid-proxy
```

**Common issues:**
- Certificate files missing: Run `./scripts/generate-ca.sh`
- Permissions: Check `chmod 600 certs/ca.key`
- Port in use: Check `sudo netstat -tulpn | grep 3128`

### No DLP Alerts for HTTPS Traffic

**Verify the chain:**

1. **Is traffic going through Squid?**
   ```bash
   docker-compose logs squid-proxy | grep CONNECT
   ```

2. **Is Squid forwarding to Envoy?**
   ```bash
   docker-compose logs envoy-proxy | grep dlp
   ```

3. **Is Envoy writing DLP logs?**
   ```bash
   tail -f logs/dlp_alerts.log
   ```

### Certificate Database Errors

If Squid shows SSL certificate generation errors:

```bash
# Stop the proxy
./scripts/manage-proxy.sh stop

# Clean SSL database
rm -rf ssl-bump/*

# Restart
./scripts/manage-proxy.sh start
```

## Performance Considerations

HTTPS inspection adds overhead:

- **CPU:** Encryption/decryption is CPU-intensive
- **Latency:** Adds ~50-100ms per request
- **Memory:** Certificate caching uses RAM

For high-traffic environments:
- Use a dedicated server with multiple CPU cores
- Consider SSL hardware accelerators
- Implement caching strategies
- Monitor resource usage

## Monitoring HTTPS Inspection

### Check Squid Statistics

```bash
docker exec squid-dlp-proxy squidclient mgr:info
```

### View SSL Bump Activity

```bash
docker exec squid-dlp-proxy tail -f /var/log/squid/access.log | grep CONNECT
```

### Monitor Certificate Generation

```bash
docker exec squid-dlp-proxy ls -lh /var/lib/squid/ssl_db/
```

## Disabling HTTPS Inspection

To revert to HTTP-only inspection:

1. Update client proxy settings to use port 8080 (Envoy) instead of 3128 (Squid)
2. Or stop Squid container:
   ```bash
   docker stop squid-dlp-proxy
   ```

## Advanced Configuration

### Custom Certificate Lifetime

Edit `config/squid.conf`:

```conf
sslproxy_cert_adapt setValidAfter all -1
sslproxy_cert_adapt setValidBefore all +365
```

### Multiple CA Certificates

For different client groups, generate separate CAs:

```bash
./scripts/generate-ca.sh team-a
./scripts/generate-ca.sh team-b
```

### Logging Specific Domains

Add to `config/squid.conf`:

```conf
acl sensitive_domains dstdomain .bank.com .internal.company.com
access_log /var/log/squid/sensitive.log combined sensitive_domains
```

## Best Practices

1. **Test thoroughly** before production deployment
2. **Document** which systems have the CA installed
3. **Rotate CA certificates** periodically (e.g., annually)
4. **Monitor** DLP alerts regularly
5. **Audit** who has access to the proxy server
6. **Backup** CA certificates securely
7. **Review** DLP patterns regularly
8. **Update** Squid and Envoy regularly for security patches

## Resources

- [Squid SSL Bump Documentation](http://www.squid-cache.org/Doc/config/ssl_bump/)
- [Envoy TLS Documentation](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/security/ssl)
- [Certificate Pinning Explained](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)

## Support

For issues with HTTPS inspection:
1. Check logs: `./scripts/manage-proxy.sh logs`
2. Verify certificates: `openssl x509 -in certs/ca.pem -text -noout`
3. Test connectivity: `./scripts/configure-client.sh test PROXY_IP 3128`
