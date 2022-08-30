This directory contains Open API Spec documentation for the APIs in the my_health module.

API specs are manually created in YAML, and served via the apidocs controller. Definitions are split across the main `openapi.yaml` and multiple schema files in the `schemas` subdirectory.

After updating an API spec, you should also re-generate the merged (single-file) version `openapi_merged.yaml` and 
add that to your pull request, since that is what is served by the apidocs controller.

To generate the merged version of the Open API Spec:

* Install `redocly` via npm: `npm install @redocly/cli -g`
* Run `sh merge_api_docs.sh`

You can also generate a locally-browsable HTML version of the API specs:

* Install `redoc-cli` via npm: `npm install redoc-cli -g`
* Run `sh generate_html_docs.sh`
* Open `index.html` in your browser.
