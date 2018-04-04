# Display the Swagger Doc
- The doc is served from the endpoint: `GET` `v0/apidocs`

# Run the Swagger UI Container
## Option 1: Run it Locally from Filesystem
_Note: This option doesn't work in Chrome because Chrome doesn't allow a null CORS Origin. Use Safari or use Option 2 or 3 below._
1. Add `null` to `web_origin` in your `settings.local.yml`:
```
# For CORS requests; separate multiple origins with a comma
web_origin: http://localhost:3000,http://localhost:3001,null
```
2. Clone the repo at: https://github.com/swagger-api/swagger-ui
3. Navigate to YOUR_SWAGGER_REPO/dist/
4. Open `index.html` in your browser
5. Paste `http://localhost:3000/v0/apidocs` into the search box and click "Explore"

## Option 2: Run it Locally from a Webserver
1. Add `localhost:8000` to `web_origin` in your `settings.local.yml`:
```
# For CORS requests; separate multiple origins with a comma
web_origin: http://localhost:3000,http://localhost:3001,localhost:8000
```
2. Clone the repo at: https://github.com/swagger-api/swagger-ui
3. Navigate to YOUR_SWAGGER_REPO/dist/
4. Run your favorite local http server to serve the current directory:
```
python -m SimpleHTTPServer 8000 # python 2
python -m http.server           # python 3
devd .                          # ("brew install devd" to install)
```
5. Open `http://localhost:8000` in your browser
6. Paste `http://localhost:3000/v0/apidocs` into the search box and click "Explore"

## Option 3: Use PetStore
1. Add `http://petstore.swagger.io/` to `web_origin` in your `settings.local.yml`
```
# For CORS requests; separate multiple origins with a comma
web_origin: http://localhost:3000,http://localhost:3001,http://petstore.swagger.io
```
2. Navigate to http://petstore.swagger.io/
3. Paste `http://localhost:3000/v0/apidocs` into the search box and click "Explore"
