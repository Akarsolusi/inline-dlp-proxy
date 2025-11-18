# Client Proxy Removal Guide

This guide explains how to completely remove the DLP proxy configuration from client machines.

## Quick Removal

On the **client machine**, run:

```bash
sudo ./configure-client.sh remove
```

## What Gets Removed

The enhanced removal script now cleans up:

1. ✅ **System environment variables** (`/etc/environment`)
   - HTTP_PROXY, HTTPS_PROXY, http_proxy, https_proxy
   - NO_PROXY, no_proxy

2. ✅ **APT proxy configuration** (`/etc/apt/apt.conf.d/95proxies`)
   - Allows apt/apt-get to work without proxy

3. ✅ **Docker proxy configuration** (`/etc/systemd/system/docker.service.d/http-proxy.conf`)
   - Removes Docker daemon proxy settings
   - Automatically restarts Docker if running

4. ✅ **Profile scripts** (`/etc/profile.d/proxy.sh`)
   - Removes any shell profile proxy configurations

5. ✅ **Creates unset script** for current shell sessions
   - Generates `/tmp/unset_proxy_*.sh` to clear current terminal

## Example Output

```bash
$ sudo ./configure-client.sh remove
[INFO] Removing proxy configuration...
[INFO] ✓ Removed proxy from /etc/environment
[INFO] ✓ Removed APT proxy configuration
[INFO] ✓ Removed Docker proxy configuration and restarted Docker

[INFO] Proxy configuration removed successfully! (3 items cleaned)

[WARNING] To apply changes immediately in your current terminal:
  source /tmp/unset_proxy_1731253200.sh

[WARNING] Or close this terminal and open a new one

[INFO] Verification:
  After sourcing, run: env | grep -i proxy
  Should return nothing (or only system defaults)

[INFO] Checking for remaining proxy settings...
[INFO] ✓ All system proxy configurations removed successfully
```

## Apply Changes to Current Terminal

The script creates a temporary unset script. Use it to clear your current session:

```bash
# The script tells you the exact command
source /tmp/unset_proxy_1731253200.sh

# Verify proxy is gone
env | grep -i proxy
# Should return nothing
```

## Alternative: New Terminal

Instead of sourcing the unset script, you can simply:

1. Close the current terminal
2. Open a new terminal
3. New sessions automatically won't have proxy

Or logout/login for system-wide effect.

## Verification Steps

After removal, verify the cleanup:

```bash
# 1. Check environment variables
env | grep -i proxy
# Should return nothing (or only system defaults like no_proxy=localhost)

# 2. Check /etc/environment
cat /etc/environment | grep -i proxy
# Should return nothing

# 3. Check APT configuration
ls -la /etc/apt/apt.conf.d/95proxies
# Should say "No such file or directory"

# 4. Check Docker configuration (if Docker installed)
ls -la /etc/systemd/system/docker.service.d/http-proxy.conf
# Should say "No such file or directory"

# 5. Test direct internet connection
curl -v https://www.google.com 2>&1 | grep -i proxy
# Should not mention any proxy
```

## Complete Cleanup (Including CA Certificate)

To fully remove all traces including the CA certificate:

```bash
# 1. Remove proxy configuration
sudo ./configure-client.sh remove

# 2. Source the unset script (path shown in output)
source /tmp/unset_proxy_*.sh

# 3. Remove mitmproxy CA certificate
sudo rm -f /usr/local/share/ca-certificates/mitmproxy-ca.crt
sudo rm -f /usr/local/share/ca-certificates/mitmproxy-ca.pem

# 4. Update CA certificates
sudo update-ca-certificates --fresh

# 5. Verify CA removed
ls -la /usr/local/share/ca-certificates/ | grep mitmproxy
# Should return nothing

# 6. Logout and login (or reboot)
logout
```

## Troubleshooting

### Proxy Still Shows in `env | grep -i proxy`

**Cause**: Current shell session still has variables set

**Solution**: Run the unset script:
```bash
source /tmp/unset_proxy_*.sh
```

Or close terminal and open a new one.

### APT Still Using Proxy

**Cause**: Other APT proxy configs exist

**Check**:
```bash
apt-config dump | grep -i proxy
```

**Solution**: Remove any other proxy configs:
```bash
sudo rm -f /etc/apt/apt.conf.d/*proxy*
```

### Docker Still Using Proxy

**Cause**: Docker needs daemon reload

**Solution**:
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### Proxy Returns After Reboot

**Cause**: Proxy set in user's `.bashrc`, `.profile`, or other shell files

**Check**:
```bash
grep -i proxy ~/.bashrc ~/.profile ~/.bash_profile
```

**Solution**: Remove proxy lines from those files manually.

## What If Script Doesn't Exist on Client?

If you don't have the configure-client.sh script, remove manually:

```bash
# 1. Edit /etc/environment
sudo nano /etc/environment
# Delete all lines with HTTP_PROXY, http_proxy, etc.

# 2. Remove APT proxy
sudo rm -f /etc/apt/apt.conf.d/95proxies

# 3. Remove Docker proxy
sudo rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
sudo systemctl daemon-reload
sudo systemctl restart docker

# 4. Unset in current shell
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy

# 5. Logout/login
logout
```

## Script Features

The enhanced removal script:
- ✅ Counts how many items were cleaned
- ✅ Automatically creates unset script for current sessions
- ✅ Verifies cleanup was successful
- ✅ Restarts Docker if needed
- ✅ Provides clear instructions for immediate effect
- ✅ Shows verification commands

## Prevention

To avoid needing proxy later, consider:
- Document which clients have/had proxy configured
- Use configuration management (Ansible, etc.) for large deployments
- Keep the configure-client.sh script for easy removal

---

**After removal, the client will connect directly to the internet without DLP inspection.**
