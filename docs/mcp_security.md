# MCP Security Configuration Guide

This document outlines how to securely configure Coverband's Model Context Protocol (MCP) server for production use, including accessing production coverage data from development environments.

## Security Overview

Coverband's MCP server can expose sensitive data including:
- Source code coverage statistics
- File structure and line-by-line coverage data  
- Dead method analysis revealing code architecture
- Route, view, and translation usage patterns

**⚠️ IMPORTANT: MCP is disabled by default for security reasons.**

## Quick Start - Development Environment

For local development with basic security:

```ruby
# config/initializers/coverband.rb
Coverband.configure do |config|
  config.mcp_enabled = true
  config.mcp_password = 'dev-password-123'  # Use strong password in production
end
```

Or via environment variables:
```bash
export COVERBAND_MCP_PASSWORD=dev-password-123
```

## Production Security Configuration

### 1. Enable MCP with Strong Authentication

```ruby
# config/initializers/coverband.rb  
Coverband.configure do |config|
  # Enable MCP only in allowed environments
  config.mcp_enabled = true
  
  # Strong authentication (required for production)
  config.mcp_password = ENV['COVERBAND_MCP_PASSWORD'] 
  
  # Restrict to specific environments
  config.mcp_allowed_environments = %w[production staging]
end
```

### 2. Environment Variables

Set secure environment variables in production:

```bash
# Strong, unique password for MCP access
export COVERBAND_MCP_PASSWORD="$(openssl rand -base64 32)"

# Optional: Restrict Rails environment (auto-detected if not set)
export RAILS_ENV=production
```

### 3. Network Security

#### Option A: VPN/Private Network (Recommended)
- Run MCP server on private network only
- Access via VPN from development machines
- Use firewall rules to restrict access

#### Option B: Reverse Proxy with Additional Auth
```nginx
# nginx configuration
location /mcp {
    # Additional HTTP Basic Auth layer
    auth_basic "Coverband MCP";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    # Rate limiting
    limit_req zone=mcp burst=10;
    
    # Proxy to MCP server
    proxy_pass http://localhost:9023/mcp;
    proxy_set_header Authorization "Bearer ${COVERBAND_MCP_PASSWORD}";
}
```

#### Option C: SSH Tunnel (Secure Remote Access)
From development machine:
```bash
# Create secure tunnel to production MCP server
ssh -L 9023:localhost:9023 production-server

# Now access MCP locally via tunnel
curl -H "Authorization: Bearer your-mcp-password" \
     -H "Content-Type: application/json" \
     -X POST http://localhost:9023/mcp \
     -d '{"method":"tools/list"}'
```

## MCP Server Deployment

### 1. Standalone HTTP Server

```ruby
# script/mcp_server.rb
require 'coverband/mcp'

Coverband.configure do |config|
  config.mcp_enabled = true
  config.mcp_password = ENV['COVERBAND_MCP_PASSWORD']
  config.mcp_allowed_environments = %w[production]
end

server = Coverband::MCP::Server.new
server.run_http(port: 9023, host: "127.0.0.1")  # Bind to localhost only
```

### 2. Rack Application Integration

```ruby
# config.ru
require 'coverband/mcp'

# Mount MCP endpoint alongside web UI
map "/coverage" do
  run Coverband::MCP::HttpHandler.new(Coverband::Reporters::Web.new)
end

# Access MCP at POST /coverage/mcp
```

### 3. systemd Service (Linux)

```ini
# /etc/systemd/system/coverband-mcp.service
[Unit]
Description=Coverband MCP Server
After=network.target

[Service]
Type=simple
User=deployer
WorkingDirectory=/app
ExecStart=/usr/local/bin/ruby /app/script/mcp_server.rb
Environment=RAILS_ENV=production
Environment=COVERBAND_MCP_PASSWORD=your-secure-password
Restart=always

[Install]
WantedBy=multi-user.target
```

## Development Environment Setup

### Accessing Production MCP Data

1. **Set up secure tunnel**:
```bash
# SSH tunnel to production
ssh -L 9023:localhost:9023 production-server
```

2. **Configure development environment**:
```ruby
# config/environments/development.rb
Coverband.configure do |config|
  config.mcp_enabled = true
  
  # Use production MCP password for access
  config.mcp_password = ENV['PRODUCTION_MCP_PASSWORD']
end
```

3. **AI Assistant Configuration**:
```json
{
  "mcp": {
    "servers": {
      "coverband-production": {
        "command": "curl",
        "args": [
          "-H", "Authorization: Bearer ${PRODUCTION_MCP_PASSWORD}",
          "-H", "Content-Type: application/json", 
          "http://localhost:9023/mcp"
        ],
        "description": "Production Coverband coverage data"
      }
    }
  }
}
```

## Security Best Practices

### 1. Password Management
- Use long, random passwords (32+ characters)
- Rotate passwords regularly
- Store in secure secret management (AWS Secrets Manager, etc.)
- Never commit passwords to version control

### 2. Access Control
- Restrict MCP to specific environments
- Use IP allowlists when possible
- Implement rate limiting
- Monitor access logs

### 3. Network Security  
- Run on private networks only
- Use HTTPS/TLS for all communications
- Implement proper firewall rules
- Consider VPN requirements

### 4. Monitoring
- Log all MCP access attempts
- Set up alerts for unusual activity
- Monitor for failed authentication
- Track usage patterns

## Troubleshooting

### MCP Not Starting
```
❌ ERROR: MCP is not enabled for security reasons.
```
**Solution**: Set `config.mcp_enabled = true` and ensure current environment is in `mcp_allowed_environments`.

### Authentication Failed
```
401 Unauthorized - Authentication required
```
**Solution**: Ensure `Authorization: Bearer <password>` header is set with correct MCP password.

### Environment Not Allowed
**Solution**: Add current environment to `mcp_allowed_environments` array.

## Security Checklist

- [ ] MCP password is strong and unique
- [ ] Password stored securely (not in code)
- [ ] MCP restricted to necessary environments only
- [ ] Network access properly secured (VPN/firewall)
- [ ] Access logging enabled
- [ ] Regular security reviews scheduled
- [ ] Incident response plan includes MCP access

## Example Production Configuration

```ruby
# config/initializers/coverband.rb
Coverband.configure do |config|
  # Standard coverband config...
  config.store = Coverband::Adapters::RedisStore.new(Redis.new)
  
  # MCP Security Configuration
  config.mcp_enabled = Rails.env.production? || Rails.env.staging?
  config.mcp_password = ENV.fetch('COVERBAND_MCP_PASSWORD') { 
    raise 'COVERBAND_MCP_PASSWORD environment variable required for MCP access'
  }
  config.mcp_allowed_environments = %w[production staging]
end
```

This configuration ensures:
- MCP only enabled in production/staging
- Strong password required via environment variable
- Fails fast if password not configured
- Clear environment restrictions