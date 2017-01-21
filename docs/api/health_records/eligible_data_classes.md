# /health_records/eligible_data_classes

##### Example query

GET /health_records/eligible_data_classes

##### Example response

```javascript
< HTTP/1.1 200 OK
< X-Frame-Options: SAMEORIGIN
< X-XSS-Protection: 1; mode=block
< X-Content-Type-Options: nosniff
< Content-Type: application/json; charset=utf-8
< ETag: W/"3ebc6566c46674fa45ede30810f22291"
< Cache-Control: max-age=0, private, must-revalidate
< X-Request-Id: dcfa1460-68b8-401d-b0f1-d53d496a1aec
< X-Runtime: 0.739656
< Vary: Origin
< Transfer-Encoding: chunked

{
  "data": {
    "id": "d101ca2db427ecfb9cb1854d0638b326dad3e74bf2b121d3066dba0e8fec6856",
    "type": "eligible_data_classes",
    "attributes": {
      "data_classes": [
        "seiactivityjournal",
        "seiallergies",
        "seidemographics",
        "familyhealthhistory",
        "seifoodjournal",
        "healthcareproviders",
        "healthinsurance",
        "seiimmunizations",
        "labsandtests",
        "medicalevents",
        "medications",
        "militaryhealthhistory",
        "seimygoalscurrent",
        "seimygoalscompleted",
        "treatmentfacilities",
        "vitalsandreadings",
        "prescriptions",
        "medications",
        "vaallergies",
        "vaadmissionsanddischarges",
        "futureappointments",
        "pastappointments",
        "vademographics",
        "vaekg",
        "vaimmunizations",
        "vachemlabs",
        "vaprogressnotes",
        "vapathology",
        "vaproblemlist",
        "varadiology",
        "vahth",
        "wellness",
        "dodmilitaryservice"
      ]
    }
  },
  "meta": {
    "updated_at": null,
    "failed_station_list": null
  }
}
```
