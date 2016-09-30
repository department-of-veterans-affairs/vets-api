# Education Benefits Claims API
* Purpose: Submit an education benefits claim
* HTTP Method: POST
* Path: /v0/education_benefits_claims
* Header for converting from/to camelcase: `X-Key-Inflection: camel`
* Parameters:
```javascript
{
  educationBenefitsClaim: {
    // validated against education benefits schema in vets-json-schema
    // must be a JSON string otherwise the middleware will convert all
    // the keys to under_score case and it will fail the schema validation
    form: formObjectAsJsonString 
  }
}
```
* Example request:
```
POST /v0/education_benefits_claims HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
X-Key-Inflection: camel

{
  "educationBenefitsClaim": {
    "form": "{\"preferredContactMethod\":\"mail\"}"
  }
}
```
* Example response:
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": {
    "id": "18",
    "type": "education_benefits_claims",
    "attributes": {
      // the form that was submitted
      "form": "{\"preferredContactMethod\":\"mail\"}",
      // when it was first submitted
      "submittedAt": "2016-09-09T23:48:07.766Z",
      // address of the VA regional office where it will be processed
      "regionalOffice": "Eastern Region\nVA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616",
      "confirmationNumber": "vets_gov_education_benefits_claim_18"
    }
  }
}
```
