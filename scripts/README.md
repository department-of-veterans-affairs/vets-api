# Local Proxy Server

A development proxy server for the VA.gov Medical Records API that provides FHIR pagination simulation and request forwarding capabilities.

## Overview

The `local-proxy.js` script creates an HTTP proxy server that intercepts specific FHIR API requests and serves mock data for testing pagination scenarios, while forwarding all other requests to the target HTTPS server.

## Features

- **FHIR Pagination Simulation**: Intercepts FHIR Observation (Vitals) requests and serves paginated mock data
- **Request Forwarding**: Proxies all other requests to the target HTTPS server
- **Error Simulation**: Provides configurable error responses for testing error handling
- **Structured Logging**: Includes timestamp-based logging following vets-api patterns

## Configuration

### Ports
- **Proxy Server**: Listens on `http://localhost:2004`
- **Target Server**: Forwards to `https://localhost:2003`

### Mock Data Files
The proxy serves mock JSON responses from the `mr/` directory:
- `vitals_page_1.json` - First page of vitals data
- `vitals_page_2.json` through `vitals_page_5.json` - Subsequent pages

## Usage

### Prerequisites

To use the proxy with your local vets-api development environment:

1. **Update settings.local.yml**: Change the FHIR endpoint configuration:
   - Change port from `2003` to `2004`
   - Change protocol from `https` to `http`

2. **Ensure AWS tunnel is running**: Your AWS tunnel should be running normally on port 2003

### Starting the Server

```bash
node scripts/local-proxy.js
```

The server will start and display:
```
Proxy server listening on http://localhost:2004, forwarding to https://localhost:2003
```

### Making Requests

Point your application to use `http://localhost:2004` instead of the original FHIR endpoint. The proxy will:

1. **FHIR Vitals Requests**: Intercept and serve mock paginated data
2. **Other Requests**: Forward to the target server at `https://localhost:2003`

## Request Handling

### Intercepted Requests

The proxy intercepts requests matching these patterns:

1. **FHIR Observation Endpoint**: `/v1/fhir/Observation`
2. **Pagination URLs**: Containing `_getpages=a97adfd5-4342-4406-b316-95dab282c425`

### Pagination Logic

For paginated requests, the proxy:
- Serves `vitals_page_1.json` for initial Observation requests
- Serves `vitals_page_2.json` through `vitals_page_5.json` based on `_getpagesoffset` parameter
- Returns HTTP 500 error for unmatched pagination requests to simulate server errors

### Forwarded Requests

All non-intercepted requests are proxied to `https://localhost:2003` with:
- Original HTTP method preserved
- All headers forwarded
- Request body streamed
- SSL verification disabled (for self-signed certificates)

## Development

### Error Handling

The proxy includes comprehensive error handling:
- **JSON File Loading**: Graceful fallback when mock files are missing
- **Proxy Errors**: Returns HTTP 502 "Bad Gateway" for upstream connection issues
- **Logging**: Structured error messages with timestamps

### Mock Data Structure

Mock JSON files should follow FHIR Bundle format:
```json
{
  "resourceType": "Bundle",
  "entry": [...],
  "link": [
    {
      "relation": "next",
      "url": "..."
    }
  ]
}
```

### Adding New Mock Endpoints

To add new mock endpoints:

1. Create JSON files in the `mr/` directory
2. Add URL pattern matching in the main request handler
3. Use the `loadJsonFile()` helper to load your mock data

Example:
```javascript
if (req.url.includes("/v1/fhir/AllergyIntolerance")) {
  const mockData = loadJsonFile('./scripts/mr/allergies.json');
  if (mockData) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(mockData));
    return;
  }
}
```

## Testing Scenarios

The proxy is designed to support these testing scenarios:

1. **Pagination Testing**: Verify multi-page FHIR resource retrieval
2. **Error Handling**: Test application behavior with server errors
3. **Performance Testing**: Simulate slow or unreliable upstream services
4. **Development Workflow**: Work with consistent mock data during development

## Troubleshooting

### Common Issues

1. **Port Already in Use**: Ensure port 2004 is available
2. **Mock Files Not Found**: Verify JSON files exist in `scripts/mr/` directory  
3. **SSL Errors**: The proxy disables SSL verification for self-signed certificates
4. **Proxy Connection Errors**: Ensure target server is running on port 2003

### Logging

The proxy provides detailed logging for debugging:
- All incoming requests are logged
- JSON file loading errors are logged
- Proxy connection errors are logged
- Pagination matches are logged

## Dependencies

- Node.js built-in modules:
  - `http` - HTTP server creation
  - `https` - HTTPS client requests
  - `fs` - File system operations
  - `path` - Path manipulation

No external npm packages required.

## Related Files

- `scripts/mr/vitals_page_*.json` - Mock FHIR data files
- `lib/medical_records/client.rb` - Ruby client that uses this proxy
- `spec/lib/medical_records/client_spec.rb` - Tests that utilize pagination features
