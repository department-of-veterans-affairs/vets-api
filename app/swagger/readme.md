# Display the Swagger Doc
- The doc is served from the endpoint: `GET` `v0/apidocs`

# Run the Swagger Doc Container
## Option 1: Run it Locally
1. Add `null` to `web_origin` in your `settings.local.yml`:
```
# For CORS requests; separate multiple origins with a comma
web_origin: http://localhost:3000,http://localhost:3001,null
```
2. Clone the repo at: https://github.com/swagger-api/swagger-ui
3. Navigate to YOUR_SWAGGER_REPO/dist/
4. Run `index.html` from file
5. Paste `http://localhost:3000/v0/apidocs` into the search box and click "Explore"

## Option 2: Use PetStore
1. Add `http://petstore.swagger.io/` to `web_origin` in your `settings.local.yml`
```
# For CORS requests; separate multiple origins with a comma
web_origin: http://localhost:3000,http://localhost:3001,http://petstore.swagger.io
```
2. Navigate to http://petstore.swagger.io/
3. Paste `http://localhost:3000/v0/apidocs` into the search box and click "Explore"
