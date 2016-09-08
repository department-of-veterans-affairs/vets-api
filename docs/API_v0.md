# API v0

## Education Benefits Claims
* Purpose: Submit an education benefits claim
* HTTP Method: POST
* Path: /v0/education_benefits_claims
* Parameters:
```javascript
{
  educationBenefitsClaim: {
    form: formObject // validated against education benefits schema in vets-json-schema
  }
}
```
* Example request:
```
POST /v0/education_benefits_claims HTTP/1.1
Host: www.vets.gov
Content-Type: application/json

{"educationBenefitsClaim":{"form":{"chapter30":true}}}
```
* Example response:
```
HTTP/1.1 200 OK
Content-Type: application/json

{"id":1,"submitted_at":"2016-08-31T21:28:36.365Z","processed_at":null,"form":{"chapter30":true},"created_at":"2016-08-31T21:28:36.365Z","updated_at":"2016-08-31T21:28:36.365Z"}
```
