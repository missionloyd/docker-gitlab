# Tailscale Setup for GitLab + Balancer

## Prerequisites

- Tailscale installed on the server and all client machines
- Server joined to the tailnet
- Cloudflare DNS managing your domain

## 1. Get the Server's Tailscale IP

On the server:

```bash
tailscale ip -4
```

## 2. Update Cloudflare DNS

In the Cloudflare dashboard for your domain:

1. Update the `script.<domain>` A record to point to the Tailscale IP
2. Delete the AAAA record for `script.<domain>`
3. Set all records to **DNS only** (no proxy)

All CNAME records pointing to `script.<domain>` will resolve to the Tailscale IP automatically.

## 3. Regenerate GitLab SSL Cert with SANs

On the server:

```bash
cd /srv/docker/gitlab/gitlab/certs/
sudo openssl genrsa -out gitlab.key 2048
sudo openssl req -new -key gitlab.key -out gitlab.csr -subj "/CN=gitlab.<domain>"
echo "subjectAltName=DNS:gitlab.<domain>" > /tmp/san.cnf
sudo openssl x509 -req -days 3650 -in gitlab.csr -signkey gitlab.key -extfile /tmp/san.cnf -out gitlab.crt
rm /tmp/san.cnf
sudo chmod 400 gitlab.key
```

Restart GitLab:

```bash
cd /path/to/docker-gitlab
docker compose -f docker-compose-ssl.yml restart gitlab
```

## 4. Trust the GitLab Cert on Each Runner

On each runner machine:

Runner config template (`/etc/gitlab-runner/config.toml`):

```toml
concurrent = 1
check_interval = 0
connection_max_age = "15m0s"
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "<runner-name>"
  url = "https://gitlab.<domain>:8443"
  clone_url = "https://gitlab.<domain>:8443"
  id = 0
  token = "<runner-token>"
  token_obtained_at = 0001-01-01T00:00:00Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  environment = ["GIT_SSL_NO_VERIFY=1"]
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "docker:26.1.4"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/cache"]
    shm_size = 0
    network_mtu = 0
```

Trust the GitLab cert and restart:

```bash
openssl s_client -connect gitlab.<domain>:8443 </dev/null 2>/dev/null | openssl x509 -out /tmp/gitlab.crt
sudo cp /tmp/gitlab.crt /usr/local/share/ca-certificates/gitlab.crt
sudo update-ca-certificates
sudo systemctl restart gitlab-runner
```

Verify:

```bash
sudo gitlab-runner verify
```

## 5. Git Client SSL Config

For git operations against the self-signed GitLab instance:

```bash
git config --global http.https://gitlab.<domain>:8443.sslVerify false
```
