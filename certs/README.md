# Certificates Directory

This directory contains SSL/TLS certificates used by the DLP proxy for HTTPS inspection.

**⚠️ IMPORTANT:** Certificate files are excluded from Git for security reasons.

## Generating Certificates

### For Mitmproxy

Mitmproxy automatically generates its CA certificate on first run. The certificate will be created at:
- `~/.mitmproxy/mitmproxy-ca-cert.pem`

After starting the containers, copy the mitmproxy certificate:

```bash
# Start the containers first
docker-compose up -d

# The mitmproxy certificate will be auto-generated
# You can find it in the mitmproxy-data volume
```

### For Envoy (if needed)

If you need to generate certificates for Envoy:

```bash
# Generate CA certificate and key
openssl req -x509 -newkey rsa:4096 -keyout ca.key -out ca.pem -days 365 -nodes \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=DLP-Proxy-CA"

# Convert to CRT format
openssl x509 -in ca.pem -out ca.crt
```

## Required Files

The following certificate files are needed:
- `ca.crt` - CA certificate (CRT format)
- `ca.pem` - CA certificate (PEM format)
- `ca.key` - CA private key
- `mitmproxy-ca-cert.pem` - Mitmproxy CA certificate
- `mitmproxy-ca-key.pem` - Mitmproxy CA private key

## Installing CA Certificate

To trust the proxy's certificate, install it on your system:

### Linux
```bash
sudo cp certs/ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### macOS
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt
```

### Windows
```powershell
certutil -addstore -f "ROOT" certs/ca.crt
```

## Security Notes

- Never commit certificate files to version control
- Regenerate certificates regularly
- Use separate certificates for production environments
- Keep private keys secure and encrypted
