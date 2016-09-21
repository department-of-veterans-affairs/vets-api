# Disability Benefits Claims API

## GET /claims
* Get a list of all open and historical claims
* Header for converting from/to camelcase: `X-Key-Inflection: camel`
* Example request:
```
GET /v0/claims HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
X-Key-Inflection: camel
```
* Example response:
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [
    {
      "id": "600022001",
      "type": "disability_claims",
      "attributes": {
        "date_filed": "02/01/2015",
        "min_est_date": null,
        "max_est_date": null,
        "tracked_items": {

        },
        "phase_dates": {
          "current_phase_back": false,
          "ever_phase_back": false,
          "phase_change_date": "02/27/2015"
        },
        "open": true,
        "waiver_submitted": false
      }
    },
    {
      "id": "600022000",
      "type": "claims",
      "attributes": {
        "date_filed": "02/01/2015",
        "min_est_date": null,
        "max_est_date": null,
        "tracked_items": {

        },
        "phase_dates": {
          "current_phase_back": false,
          "ever_phase_back": false,
          "phase_change_date": "02/27/2015"
        },
        "open": true,
        "waiver_submitted": false
      }
    }
  ]
}
```

## GET /claims/:id
* Get a single claim
* Header for converting from/to camelcase: `X-Key-Inflection: camel`
* Example request:
```
GET /v0/claims/189625 HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
X-Key-Inflection: camel
```
* Example response:
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": {
    "id": "189625",
    "type": "claims",
    "attributes": {
      "date_filed": "09\/23\/2008",
      "min_est_date": "05\/02\/2013",
      "max_est_date": "01\/02\/2014",
      "tracked_items": {
        "never_received_from_others_list": [

        ],
        "never_received_from_you_list": [

        ],
        "received_from_others_list": [
          {
            "description": "21-4142",
            "displayed_name": "Request 9",
            "overdue": false,
            "received_date": "02\/17\/2010",
            "tracked_item_id": 1,
            "tracked_item_status": "ACCEPTED",
            "uploaded": false,
            "uploads_allowed": false
          },
          {
            "description": "What was received item one.",
            "displayed_name": "Request 10",
            "overdue": false,
            "received_date": "08\/29\/2012",
            "tracked_item_id": 2,
            "tracked_item_status": "ACCEPTED",
            "uploaded": false,
            "uploads_allowed": false
          },
          {
            "description": "What was received item two.",
            "displayed_name": "Request 11",
            "overdue": false,
            "received_date": "09\/24\/2012",
            "tracked_item_id": 4,
            "tracked_item_status": "ACCEPTED",
            "uploaded": true,
            "uploads_allowed": false,
            "vba_documents": [
              {
                "corporate_document_id": 4,
                "document_id": "{uuid4}",
                "document_size": 0,
                "document_type_code": "L102",
                "document_type_id": "111",
                "document_type_label": "VA 21-2680 Examination for Housebound Status or Permanent Need for Regular Aid and Attendance",
                "file_name": "name4",
                "mime_type": "application\/pdf",
                "original_file_name": "name4",
                "receipt_date": 1427342400000,
                "source": "EBN",
                "submitter": {
                  "first_name": "Andrew",
                  "last_name": "Luck",
                  "person_id": "222"
                },
                "tracked_item_id": 4,
                "upload_date": 1411474974000,
                "veteran": {
                  "file_number": "796104437",
                  "first_name": "MARK",
                  "last_name": "WEBB"
                }
              }
            ]
          },
          {
            "description": "What was received item three.",
            "displayed_name": "Request 12",
            "overdue": false,
            "received_date": "11\/29\/2012",
            "tracked_item_id": 41,
            "tracked_item_status": "ACCEPTED",
            "uploaded": false,
            "uploads_allowed": false
          }
        ],
        "received_from_you_list": [

        ],
        "still_need_from_others_list": [
          {
            "description": "Requested verification of date of birth or age at time of entrance on active duty.",
            "displayed_name": "Request 3",
            "opened_date": "03\/21\/2010",
            "overdue": false,
            "suspense_date": "05\/22\/2010",
            "tracked_item_id": 31,
            "tracked_item_status": "NEEDED",
            "uploaded": false,
            "uploads_allowed": true
          },
          {
            "description": "Requested personal history information.",
            "displayed_name": "Request 4",
            "opened_date": "03\/22\/2010",
            "overdue": false,
            "suspense_date": "05\/24\/2010",
            "tracked_item_id": 3,
            "tracked_item_status": "NEEDED",
            "uploaded": false,
            "uploads_allowed": true
          },
          {
            "description": "Requested verification of type and amount of net separation pay.",
            "displayed_name": "Request 5",
            "opened_date": "03\/23\/2010",
            "overdue": false,
            "suspense_date": "05\/21\/2010",
            "tracked_item_id": 33,
            "tracked_item_status": "NEEDED",
            "uploaded": false,
            "uploads_allowed": true
          },
          {
            "description": "Requested service record changes and corrections.",
            "displayed_name": "Request 6",
            "opened_date": "03\/23\/2010",
            "overdue": false,
            "suspense_date": "05\/27\/2010",
            "tracked_item_id": 35,
            "tracked_item_status": "NEEDED",
            "uploaded": false,
            "uploads_allowed": true
          },
          {
            "description": "Requested inpatient clinical records from &lt;clinic\/hospital name>.",
            "displayed_name": "Request 7",
            "opened_date": "03\/23\/2010",
            "overdue": false,
            "suspense_date": "05\/26\/2010",
            "tracked_item_id": 36,
            "tracked_item_status": "NEEDED",
            "uploaded": false,
            "uploads_allowed": true
          },
          {
            "description": "Requested verification of military benefit type and amount.",
            "displayed_name": "Request 8",
            "opened_date": "03\/24\/2010",
            "overdue": false,
            "suspense_date": "05\/25\/2010",
            "tracked_item_id": 32,
            "tracked_item_status": "NEEDED",
            "uploaded": false,
            "uploads_allowed": true
          }
        ],
        "still_need_from_you_list": [
          {
            "description": "What we still need from you item one.",
            "displayed_name": "Request 1",
            "opened_date": "03\/15\/2010",
            "overdue": true,
            "suspense_date": "03\/25\/2010",
            "tracked_item_id": 50,
            "tracked_item_status": "NEEDED",
            "uploaded": false,
            "uploads_allowed": true
          },
          {
            "description": "What we still need from you item two.",
            "displayed_name": "Request 2",
            "opened_date": "03\/16\/2010",
            "overdue": true,
            "suspense_date": "03\/26\/2010",
            "tracked_item_id": 51,
            "tracked_item_status": "NEEDED",
            "uploaded": false,
            "uploads_allowed": true
          }
        ]
      },
      "phase_dates": {
        "current_phase_back": false,
        "ever_phase_back": false,
        "latest_phase_type": "Complete",
        "phase1_complete_date": "10\/25\/2012",
        "phase2_complete_date": "10\/26\/2012",
        "phase3_complete_date": "10\/27\/2012",
        "phase4_complete_date": "10\/28\/2012",
        "phase5_complete_date": "10\/29\/2012",
        "phase6_complete_date": "10\/30\/2012",
        "phase7_complete_date": "10\/31\/2012",
        "phase_change_date": "10\/31\/2012",
        "phase_max_est_date": "08\/28\/2012",
        "phase_min_est_date": "07\/17\/2012",
        "phase_type_change_ind": "78"
      },
      "open": false,
      "waiver_submitted": false,
      "contention_list": [
        "Hearing Loss (New)",
        " skin condition (New)",
        " jungle rot (New)"
      ],
      "va_representative": "AMERICAN LEGION"
    }
  }
}
```

## POST /claims/:id/request_decision
* Request a decision for a claim
* Header for converting from/to camelcase: `X-Key-Inflection: camel`
* Example request:
```
POST /v0/claims/189625/request_decision HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
X-Key-Inflection: camel
```
* Example response:
```
HTTP/1.1 204 No Content
Content-Type: application/json
```

## POST /claims/:id/documents
* Add a document to a claim
* Header for converting from/to camelcase: `X-Key-Inflection: camel`
* Example request:
```
curl /v0/claims/189625/documents \
  -F tracked_item=1 \
  -F file="@/path/to/a/file.jpg"
```
* Example response:
```
HTTP/1.1 204 No Content
Content-Type: application/json
```
