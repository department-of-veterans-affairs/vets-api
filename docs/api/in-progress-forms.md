# GET /v0/in_progress_forms/:id
Given a form id as the resource identifier returns a previously saved form for the active LOA3 user.
If no form is found the endpoint returns auto-fill data. Form ids are those defined
in [vets-json-schema](vets-json-schema):

Healthcare Application: 'healthcare_application'
Education Benefits: 'edu_benefits'

Auto-fill data is generated from a user's VA profile via form mappings in `config/form_profile_mappings.yml`.

## Required Parameters
`Authorization: Token token=abcd1234...`

## Example
### Request
```
GET http://api.vets.gov/v0/in_progress_forms/healthcare_application HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
Authorization: Token token=RiW_3isZHtUszCLvEAv4vEyCV37K8yFeezQm4fdT
```

### Response
#### Form Found
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "activeDutyKicker": false,
  "additionalContributions": false,
  "bankAccount": {
    "accountNumber": "88888888888",
    "accountType": "checking",
    "bankName": "First Bank of JSON",
    "routingNumber": "123456789"
  },
  "chapter1606": true,
  "currentlyActiveDuty": {
    "nonVaAssistance": false,
    "onTerminalLeave": false,
    "yes": false
  },
  "educationType": "college",
  "faaFlightCertificatesInformation": "cert1, cert2",
  "gender": "M",
  "highSchoolOrGedCompletionDate": "2010-06-06",
  "homePhone": "5551110000",
  "postHighSchoolTrainings": [{
    "city": "New York",
    "dateRange": {
      "from": "1999-01-01",
      "to": "2000-01-01"
    },
    "degreeReceived": "BA",
    "hours": 8,
    "hoursType": "semester",
    "major": "History",
    "name": "OtherCollege Name",
    "state": "NY"
  }],
  "privacyAgreementAccepted": true,
  "reserveKicker": false,
  "school": {
    "address": {
      "city": "Baltimore",
      "country": "USA",
      "postalCode": "21231",
      "state": "MD",
      "street": "111 Uni Drive"
    },
    "educationalObjective": "...",
    "name": "FakeData University",
    "startDate": "2016-08-29"
  },
  "secondaryContact": {
    "fullName": "Sibling Olson",
    "sameAddressAndPhone": true
  },
  "serviceBefore1977": {
    "haveDependents": true,
    "married": true,
    "parentDependent": false
  },
  "toursOfDuty": [{
    "dateRange": {
      "from": "2001-01-01",
      "to": "2010-10-10"
    },
    "involuntarilyCalledToDuty": "yes",
    "serviceBranch": "Army",
    "serviceStatus": "Active Duty"
  }, {
    "dateRange": {
      "from": "1995-01-01",
      "to": "1998-10-10"
    },
    "involuntarilyCalledToDuty": "yes",
    "serviceBranch": "Army",
    "serviceStatus": "Honorable Discharge"
  }],
  "veteranAddress": {
    "street": "140 Rock Creek Church Road NW"
    "city": "Washington",
    "state": "DC",
    "country": "USA",
    "postalCode": "20011",
  },
  "veteranDateOfBirth": "1809-02-12",
  "veteranFullName": {
    "first": "Abraham",
    "last": "Lincoln"
  },
  "veteranSocialSecurityNumber": "111223333"
}
```

### Response
#### Form Not Found
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "veteranFullName": {
    "first": "Abraham",
    "middle": null,
    "last": "Lincoln",
    "suffix": null
  },
  "gender": "M",
  "veteranDateOfBirth": "1809-02-12",
  "veteranAddress": {
    "street": "140 Rock Creek Church Road NW",
    "street_2": null,
    "city": "Washington",
    "state": "DC",
    "country": "USA",
    "postal_code": "20011"
  },
  "homePhone": "2028290436"
}
```
# PUT /v0/in_progress_forms/:id
Given a form id as the resource identifier and a request body of `form_data` either inserts or updates the form in the database.
If the form is saved correctly the endpoint responds with 200 OK with a blank body.

## Required Parameters
`Authorization: Token token=abcd1234...`

## Example
### Request
```
PUT http://api.vets.gov/v0/in_progress_forms/healthcare_application HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
Authorization: Token token=RiW_3isZHtUszCLvEAv4vEyCV37K8yFeezQm4fdT

"form_data":{
  "activeDutyKicker": false,
  "additionalContributions": false,
  "bankAccount": {
    "accountNumber": "88888888888",
    "accountType": "checking",
    "bankName": "First Bank of JSON",
    "routingNumber": "123456789"
  },
  "chapter1606": true,
  "currentlyActiveDuty": {
    "nonVaAssistance": false,
    "onTerminalLeave": false,
    "yes": false
  },
  // ...
```

### Response
```
HTTP/1.1 200 OK
Content-Length: 0
```
