# Disability Benefits Claims API

## Required headers
All endpoints require an auth token, like `Authorization: Token token=abcd1234...`

## GET /disability_claims
* Get a list of all open and historical claims
* Header for converting from/to camelcase: `X-Key-Inflection: camel`
* Example request:
```
GET /v0/disability_claims HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
X-Key-Inflection: camel
Authorization: Token token=ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789abcde
```
* Example response:
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [
    {
      "attributes": {
        "currentPhaseBack": false,
        "dateFiled": "2016-12-01",
        "decisionLetterSent": false,
        "developmentLetterSent": false,
        "documentsNeeded": false,
        "everPhaseBack": false,
        "evssId": 600089260,
        "maxEstDate": null,
        "minEstDate": null,
        "open": true,
        "phase": 2,
        "phaseChangeDate": "2016-11-15",
        "requestedDecision": false,
        "updatedAt": "2016-11-17T21:38:25.660Z",
        "waiverSubmitted": false
      },
      "id": "600089260",
      "type": "disability_claims"
    },
    {
      "attributes": {
        "currentPhaseBack": false,
        "dateFiled": "2016-12-01",
        "decisionLetterSent": false,
        "developmentLetterSent": false,
        "documentsNeeded": false,
        "everPhaseBack": false,
        "evssId": 600089175,
        "maxEstDate": null,
        "minEstDate": null,
        "open": true,
        "phase": 2,
        "phaseChangeDate": "2016-11-14",
        "requestedDecision": false,
        "updatedAt": "2016-11-17T21:38:25.674Z",
        "waiverSubmitted": false
      },
      "id": "600089175",
      "type": "disability_claims"
    }
  ],
  "meta": {
    "successfulSync": true
  }
}

```

## GET /disability_claims/:id
* Get a single claim
* Header for converting from/to camelcase: `X-Key-Inflection: camel`
* Example request:
```
GET /v0/disability_claims/189625 HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
X-Key-Inflection: camel
Authorization: Token token=ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789abcde
```
* Example response:
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": {
    "attributes": {
      "claimType": "Compensation",
      "contentionList": [
        "tinnitus (Increase)",
        " headaches (Increase)"
      ],
      "currentPhaseBack": false,
      "dateFiled": "2016-12-01",
      "decisionLetterSent": false,
      "developmentLetterSent": false,
      "documentsNeeded": false,
      "eventsTimeline": [
        {
          "date": "2016-12-01",
          "type": "filed"
        },
        {
          "date": "2016-11-15",
          "documentType": "L034",
          "fileType": "Military Personnel Record",
          "filename": "jammie brooks for 526 document Upld.pdf",
          "trackedItemId": null,
          "type": "other_documents_list",
          "uploadDate": "2016-11-15"
        },
        {
          "date": "2016-11-15",
          "documentType": "L533",
          "fileType": "VA 21-526EZ, Fully Developed Claim (Compensation)",
          "filename": "Jaime_Brooks_526.pdf",
          "trackedItemId": null,
          "type": "other_documents_list",
          "uploadDate": "2016-11-15"
        },
        {
          "date": "2016-11-15",
          "documentType": "L049",
          "fileType": "Medical Treatment Record - Non-Government Facility",
          "filename": "jammie brooks VSO Claims Detail doc Upld.pdf",
          "trackedItemId": null,
          "type": "other_documents_list",
          "uploadDate": "2016-11-15"
        },
        {
          "date": "2016-11-15",
          "documentType": "L451",
          "fileType": "STR - Medical - Photocopy",
          "filename": "jammie brooks Veteran Claims Detail doc Upld.pdf",
          "trackedItemId": null,
          "type": "other_documents_list",
          "uploadDate": "2016-11-15"
        },
        {
          "date": "2016-11-15",
          "type": "phase1"
        }
      ],
      "everPhaseBack": false,
      "evssId": 600089260,
      "maxEstDate": null,
      "minEstDate": null,
      "open": true,
      "phase": 2,
      "phaseChangeDate": "2016-11-15",
      "requestedDecision": false,
      "updatedAt": "2016-11-17T21:40:28.128Z",
      "vaRepresentative": "AMERICAN LEGION",
      "waiverSubmitted": false
    },
    "id": "600089260",
    "type": "disability_claims"
  },
  "meta": {
    "successfulSync": true
  }
}
```

## POST /disability_claims/:id/request_decision
* Request a decision for a claim
* Header for converting from/to camelcase: `X-Key-Inflection: camel`
* Example request:
```
POST /v0/disability_claims/189625/request_decision HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
X-Key-Inflection: camel
Authorization: Token token=ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789abcde
```
* Example response:
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "jobId": "abcdef123456789abcdef123"
}
```

## POST /disability_claims/:id/documents
* Add a document to a claim
* Header for converting from/to camelcase: `X-Key-Inflection: camel`
* Example request:
```
curl /v0/disability_claims/189625/documents \
  -H 'Origin: https://www.vets.gov' \
  -H 'Authorization: Token token=ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789abcde' \
  -H 'Accept: application/json' \
  -H 'X-Key-Inflection: camel' \
  -F tracked_item_id=1 \
  -F document_type='L307' \
  -F file="@/path/to/a/file.jpg"
```
* Example response:
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "jobId": "abcdef123456789abcdef123"
}
```
