# X-Accel-Redirect Setup for Attachment Streaming

## Overview

This document describes the nginx/openresty configuration required to support the `mhv_secure_messaging_x_accel_redirect` feature flag, which enables memory-efficient streaming of S3 attachments.

## How It Works

1. **Client** requests attachment from vets-api
2. **vets-api** authenticates/authorizes the request
3. **vets-api** retrieves attachment metadata (S3 URL) from MHV API without downloading the file
4. **vets-api** returns `X-Accel-Redirect` header pointing to internal nginx location
5. **nginx/openresty** streams the file directly from S3 to the client
6. **vets-api** process is freed immediately (no memory usage, no blocking)

## Benefits

- **Zero memory overhead** in Rails for file content
- **Instant response** - Rails returns immediately after auth check
- **No process blocking** - Puma/Unicorn workers freed instantly
- **Direct streaming** - nginx streams from S3 to client
- **Better scalability** - handles large files without consuming Rails resources

## Required nginx/openresty Configuration

Add this configuration to the openresty/nginx config in `vsp-platform-revproxy`:

```nginx
# Internal location for streaming S3 attachments
# Only accessible via X-Accel-Redirect from vets-api
location ~ ^/internal-s3-proxy/(.*)$ {
    internal;  # Cannot be accessed directly by clients
    
    # Resolver for S3 DNS lookups
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    
    # Decode the URL-encoded S3 URL and stream it
    set_unescape_uri $s3_url $1;
    proxy_pass $s3_url$is_args$args;
    
    # S3-specific headers
    proxy_ssl_server_name on;
    proxy_ssl_protocols TLSv1.2 TLSv1.3;
    proxy_set_header Host $proxy_host;
    
    # Streaming optimizations
    proxy_buffering off;  # Stream directly, don't buffer in nginx
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    
    # Timeouts for large files
    proxy_connect_timeout 10s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Hide S3 headers from client
    proxy_hide_header x-amz-id-2;
    proxy_hide_header x-amz-request-id;
    proxy_hide_header x-amz-meta-s3cmd-attrs;
    proxy_hide_header x-amz-server-side-encryption;
    proxy_hide_header x-amz-storage-class;
    
    # Add security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
}
```

### Configuration Notes

1. **Internal Only**: The `internal;` directive ensures this location cannot be accessed directly by clients, only via `X-Accel-Redirect` from vets-api.

2. **DNS Resolver**: AWS GovCloud S3 endpoints require DNS resolution. Update resolver IPs based on environment:
   - Development: Use local DNS
   - Staging/Production: Use VPC DNS resolver (e.g., `10.247.32.2` from prod config)

3. **Buffering**: `proxy_buffering off;` is critical for true streaming. With buffering on, nginx would load the entire file into memory.

4. **Timeouts**: Adjust based on expected file sizes and connection speeds. Current settings allow up to 60 seconds for reading, suitable for large attachments.

## Rollout Plan

### Phase 1: Infrastructure Setup (Weeks 1-2)
1. Add nginx configuration to `vsp-platform-revproxy` repo
2. Deploy to development environment
3. Verify internal location is inaccessible directly
4. Test with curl commands

### Phase 2: Development Testing (Week 3)
1. Enable feature flag in development: `Flipper.enable(:mhv_secure_messaging_x_accel_redirect)`
2. Test S3 attachment downloads
3. Verify non-S3 attachments still work (fallback path)
4. Monitor Rails logs for errors

### Phase 3: Staging Validation (Week 4)
1. Deploy nginx config to staging
2. Enable feature flag for internal users
3. Load test with various file sizes
4. Monitor memory usage, response times
5. Verify logs and error handling

### Phase 4: Production Rollout (Weeks 5-6)
1. Deploy nginx config to production
2. Gradual rollout via percentage-based feature flag
3. Monitor dashboards for:
   - Rails memory usage (should decrease)
   - Response times (should improve)
   - Error rates
   - S3 bandwidth usage

### Rollback Plan
If issues occur:
1. Disable feature flag: `Flipper.disable(:mhv_secure_messaging_x_accel_redirect)`
2. System automatically falls back to legacy in-memory streaming
3. No nginx config changes needed for rollback

## Testing

### Manual Testing
```bash
# 1. Enable feature flag in Rails console
Flipper.enable(:mhv_secure_messaging_x_accel_redirect)

# 2. Download an attachment via API
curl -H "Authorization: Bearer TOKEN" \
     https://staging-api.va.gov/my_health/v1/messaging/messages/123/attachments/456 \
     -o test-attachment.pdf

# 3. Verify response headers include X-Accel-Redirect
curl -I -H "Authorization: Bearer TOKEN" \
     https://staging-api.va.gov/my_health/v1/messaging/messages/123/attachments/456
```

### Automated Testing
See `spec/requests/my_health/v1/messaging/attachments_spec.rb` for integration tests.

## Monitoring

### Key Metrics
- **Rails memory usage**: Should decrease significantly when feature is enabled
- **Rails process blocking time**: Should drop to near-zero for attachment requests
- **Response time**: Should improve (faster initial response)
- **S3 bandwidth**: Monitor for any unexpected changes

### Dashboards
- Add Datadog/Grafana metrics for:
  - `x_accel_redirect.s3_attachments.total`
  - `x_accel_redirect.fallback.total`
  - `rails.attachments_controller.response_time`
  - `nginx.internal_s3_proxy.requests`

## Security Considerations

1. **Authentication**: vets-api still handles all auth/authorization before issuing X-Accel-Redirect
2. **URL Encoding**: S3 URLs are URL-encoded to prevent injection attacks
3. **Internal Only**: nginx location is marked `internal` and cannot be accessed directly
4. **Presigned URLs**: S3 presigned URLs have expiration (typically 15 minutes)
5. **HTTPS**: All traffic between nginx and S3 uses TLS

## Troubleshooting

### Issue: "502 Bad Gateway" errors
- **Cause**: DNS resolution failure or S3 endpoint unreachable
- **Fix**: Verify resolver configuration matches VPC DNS

### Issue: Attachments download but are empty/corrupted
- **Cause**: Incorrect URL encoding/decoding
- **Fix**: Verify `set_unescape_uri` is working correctly

### Issue: Non-S3 attachments fail
- **Cause**: Feature flag enabled but fallback not working
- **Fix**: Check `get_attachment_metadata` returns nil for non-S3 attachments

### Issue: High memory usage persists
- **Cause**: `proxy_buffering` not disabled
- **Fix**: Ensure `proxy_buffering off;` is set in nginx config

## References

- [nginx X-Accel documentation](http://nginx.org/en/docs/http/ngx_http_core_module.html#internal)
- [Rails send_file with X-Accel-Redirect](https://api.rubyonrails.org/classes/ActionController/DataStreaming.html)
- AWS S3 presigned URL documentation
