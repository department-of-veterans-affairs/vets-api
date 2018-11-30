# Display the Swagger Doc
- The doc is served from the endpoint: `GET` `v0/apidocs`

# Run the Swagger UI Container
## Option 1: Run it Locally from Filesystem
1. Clone the repo at: https://github.com/swagger-api/swagger-ui
1. Navigate to YOUR_SWAGGER_REPO/dist/
1. Open `index.html` in your browser
1. Paste `http://localhost:3000/v0/apidocs` into the search box and click "Explore"

## Option 2: Run it Locally from a Webserver
1. Clone the repo at: https://github.com/swagger-api/swagger-ui
1. Navigate to YOUR_SWAGGER_REPO/dist/
1. Run your favorite local http server to serve the current directory:
```
python -m SimpleHTTPServer 8000 # python 2
python -m http.server           # python 3
devd .                          # ("brew install devd" to install)
```
1. Open `http://localhost:8000` in your browser
1. Paste `http://localhost:3000/v0/apidocs` into the search box and click "Explore"

## Option 3: Use PetStore
1. Navigate to http://petstore.swagger.io/
1. Paste `http://localhost:3000/v0/apidocs` into the search box and click "Explore"
