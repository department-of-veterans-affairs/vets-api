## Example Payload

The following demonstrates a form-data payload suitable for submitting to the POST endpoint if using Webhooks. If not using Webhooks, this request body is not required. 

This is an example curl command when using Webhooks:

```
'curl --location --request POST 'https://dev-api.va.gov/services/vba_documents/v2/uploads' \
--header 'apikey: <yourAPIkey>' \
--form 'observers="{
  \"subscriptions\": [
   \ {
   \   "event\": \"gov.va.developer.benefits-intake.status_change\",
   \   "urls": [
   \   	"https://i/am/listening",
   \     "https://i/am/also/listening"
   \   ]
   \ }
 \ ]
}"'
```
