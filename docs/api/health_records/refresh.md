# /health_records/refresh

##### Example query

GET /health_records/refresh

##### Important Note

While the response below is more or less instant, this response will signify when the last refresh completed. A refresh typically takes 12-15 minutes, and these are batched
and controller by MHV. They update the data from VISTA and other partners, and sometimes
this batched job may even fail.

That being said, a call to refresh will only trigger a single batch per day. That batched job should complete within 12-15 minutes, if it fails, it will be reattempted later.

The way this endpoint can be used is to call this refresh endpoint in a polling mechanism
to determine when the data has been fully refreshed. After the 12-15 minute job completes successfully, the dates returned will be updated and this can be used to show
a user that the data has been refreshed and a new report can be generated with the updated data.

##### Example response

```javascript
< HTTP/1.1 200 OK
< X-Frame-Options: SAMEORIGIN
< X-XSS-Protection: 1; mode=block
< X-Content-Type-Options: nosniff
< Content-Type: application/json; charset=utf-8
< ETag: W/"473eb5c984589fad575217406f0a012b"
< Cache-Control: max-age=0, private, must-revalidate
< X-Request-Id: a277c01a-62c8-44d5-88e4-7da25a783458
< X-Runtime: 0.731946
< Vary: Origin
< Transfer-Encoding: chunked

{
  "data": [
    {
      "id": "6f2f78d88f05a7674bd745075b05f690069f0f53043d4ce74f068d65b5141360",
      "type": "extract_statuses",
      "attributes": {
        "extract_type": "ChemistryHematology",
        "last_updated": "2017-01-19T19:37:50.000Z",
        "status": "OK",
        "created_on": "2017-01-19T19:37:47.000Z",
        "station_number": ""
      }
    },
    {
      "id": "bae35670f4df274f6b31cd29d35c3d518050099aba95c6a9be523ed53627b0f4",
      "type": "extract_statuses",
      "attributes": {
        "extract_type": "ImagingStudy",
        "last_updated": "2017-01-19T19:37:49.000Z",
        "status": "ERROR",
        "created_on": "2017-01-19T19:37:47.000Z",
        "station_number": ""
      }
    },
    {
      "id": "908252c6803b78ef3b12b7a53a430f913bf40892ec71d01e679bb6323bb7c485",
      "type": "extract_statuses",
      "attributes": {
        "extract_type": "VPR",
        "last_updated": "2017-01-19T19:37:59.000Z",
        "status": "OK",
        "created_on": "2017-01-19T19:37:47.000Z",
        "station_number": ""
      }
    },
    {
      "id": "ed0ccabccd4b006f7a03e7f7225f99a410647f3a65c5b74bc30be291b1c8a04d",
      "type": "extract_statuses",
      "attributes": {
        "extract_type": "DodMilitaryService",
        "last_updated": "2017-01-19T19:37:48.000Z",
        "status": "OK",
        "created_on": "2017-01-19T19:37:47.000Z",
        "station_number": ""
      }
    },
    {
      "id": "493c168201c9d5852fda0ff9307e84febb9dae1fbb4537ea0cd123ec6d86b12a",
      "type": "extract_statuses",
      "attributes": {
        "extract_type": "WellnessReminders",
        "last_updated": "2017-01-19T19:37:58.000Z",
        "status": "OK",
        "created_on": "2017-01-19T19:37:47.000Z",
        "station_number": ""
      }
    },
    {
      "id": "2ea8c5fd396a1f815d4648408e77957f29263b381eeb7eadc0ad2fa44691a68f",
      "type": "extract_statuses",
      "attributes": {
        "extract_type": "Allergy",
        "last_updated": "2017-01-19T19:37:52.000Z",
        "status": "OK",
        "created_on": "2017-01-19T19:37:47.000Z",
        "station_number": ""
      }
    },
    {
      "id": "0e37353d1697a9955c8653a6fc1a2297adb19f23d620f2243ac7b90ca676bcf7",
      "type": "extract_statuses",
      "attributes": {
        "extract_type": "Appointments",
        "last_updated": "2017-01-19T19:37:48.000Z",
        "status": "ERROR",
        "created_on": "2017-01-19T19:37:47.000Z",
        "station_number": ""
      }
    }
  ],
  "meta": {
    "updated_at": null,
    "failed_station_list": null
  }
```
