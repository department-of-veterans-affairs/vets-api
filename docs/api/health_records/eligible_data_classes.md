# /health_records/eligible_data_classes

##### Example query

GET /health_records/eligible_data_classes

##### Important Note

The eligible data classes endpoint should be used to determine what data is available for
a given veteran that requests a health record. The data classes map directly to the checkboxes that are selected and should be used to dynamically generate the form used to
generate the report.

There is a server side validation to ensure that the data classes passed to the generate
endpoint are a part of this request. Note also, that doing a PHR refresh may add additional eligible data classes or possibly retire old ones to reflect the updated data
that is available. As such, one should bust any caching that is done, when refreshing the data for a given day.

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
