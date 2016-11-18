# /prescriptions

##### Example query

GET prescriptions
GET prescriptions?page=1&per_page=10

##### Example response

```javascript
< HTTP/1.1 200 OK
< X-Frame-Options: SAMEORIGIN
< X-XSS-Protection: 1; mode=block
< X-Content-Type-Options: nosniff
< Content-Type: application/json; charset=utf-8
< Vary: Accept-Encoding
< ETag: W/"075c37f7efe66980041a81a635889dc1"
< Cache-Control: max-age=0, private, must-revalidate
< X-Request-Id: 7251b973fe4e4f74803da98344f9a60f
< X-Runtime: 0.073920
< Transfer-Encoding: chunked
{
  "data": [
    {
      "id": "746575",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 746575,
        "prescription-number": "2719083",
        "prescription-name": "ACETAMINOPHEN 325MG TAB",
        "refill-submit-date": null,
        "refill-date": "2014-01-24T05:00:00.000Z",
        "refill-remaining": 5,
        "facility-name": "ABC123",
        "ordered-date": "2014-01-24T05:00:00.000Z",
        "quantity": 10,
        "expiration-date": "2015-01-25T05:00:00.000Z",
        "dispensed-date": null,
        "station-number": "12",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/746575",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/746575\/tracking"
      }
    },
    {
      "id": "750338",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 750338,
        "prescription-number": "2719110",
        "prescription-name": "Drug 5 400MG TAB",
        "refill-submit-date": "2014-02-12T05:00:00.000Z",
        "refill-date": "2014-02-12T05:00:00.000Z",
        "refill-remaining": 0,
        "facility-name": "ABC123",
        "ordered-date": "2014-01-13T05:00:00.000Z",
        "quantity": 5,
        "expiration-date": "2015-01-14T05:00:00.000Z",
        "dispensed-date": "2014-02-12T05:00:00.000Z",
        "station-number": "12",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/750338",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/750338\/tracking"
      }
    },
    {
      "id": "779788",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 779788,
        "prescription-number": "2719123",
        "prescription-name": "Drug 7 15MG TAB",
        "refill-submit-date": null,
        "refill-date": "2014-07-14T04:00:00.000Z",
        "refill-remaining": 4,
        "facility-name": "ABC123",
        "ordered-date": "2014-06-19T04:00:00.000Z",
        "quantity": 5,
        "expiration-date": "2015-06-20T04:00:00.000Z",
        "dispensed-date": "2014-07-14T04:00:00.000Z",
        "station-number": "12",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/779788",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/779788\/tracking"
      }
    },
    {
      "id": "779789",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 779789,
        "prescription-number": "2719125",
        "prescription-name": "Drug 8 100MG TAB",
        "refill-submit-date": null,
        "refill-date": "2014-07-14T04:00:00.000Z",
        "refill-remaining": 5,
        "facility-name": "ABC123",
        "ordered-date": "2014-06-26T04:00:00.000Z",
        "quantity": 5,
        "expiration-date": "2015-06-27T04:00:00.000Z",
        "dispensed-date": "2014-07-14T04:00:00.000Z",
        "station-number": "12",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/779789",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/779789\/tracking"
      }
    },
    {
      "id": "776905",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 776905,
        "prescription-number": "3635911",
        "prescription-name": "Drug 7 15MG TAB",
        "refill-submit-date": "2014-07-14T04:00:00.000Z",
        "refill-date": "2014-07-14T04:00:00.000Z",
        "refill-remaining": 4,
        "facility-name": "ABC123",
        "ordered-date": "2014-06-19T04:00:00.000Z",
        "quantity": 5,
        "expiration-date": "2015-06-20T04:00:00.000Z",
        "dispensed-date": "2014-07-14T04:00:00.000Z",
        "station-number": "12",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/776905",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/776905\/tracking"
      }
    },
    {
      "id": "776925",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 776925,
        "prescription-number": "3635913",
        "prescription-name": "Drug 8 100MG TAB",
        "refill-submit-date": "2014-07-14T04:00:00.000Z",
        "refill-date": "2014-07-14T04:00:00.000Z",
        "refill-remaining": 5,
        "facility-name": "ABC123",
        "ordered-date": "2014-06-26T04:00:00.000Z",
        "quantity": 5,
        "expiration-date": "2015-06-27T04:00:00.000Z",
        "dispensed-date": "2014-07-14T04:00:00.000Z",
        "station-number": "13333",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/776925",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/776925\/tracking"
      }
    },
    {
      "id": "777736",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 777736,
        "prescription-number": "2719137",
        "prescription-name": "Drug 6 10MG TAB",
        "refill-submit-date": "2014-07-16T04:00:00.000Z",
        "refill-date": "2014-07-16T04:00:00.000Z",
        "refill-remaining": 1,
        "facility-name": "ABC123",
        "ordered-date": "2014-06-17T04:00:00.000Z",
        "quantity": 5,
        "expiration-date": "2015-06-18T04:00:00.000Z",
        "dispensed-date": "2014-07-16T04:00:00.000Z",
        "station-number": "12",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/777736",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/777736\/tracking"
      }
    },
    {
      "id": "776906",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 776906,
        "prescription-number": "2719124",
        "prescription-name": "SIROLIMUS 1MG TAB",
        "refill-submit-date": "2014-07-14T04:00:00.000Z",
        "refill-date": "2014-07-19T04:00:00.000Z",
        "refill-remaining": 4,
        "facility-name": "ABC123",
        "ordered-date": "2014-06-14T04:00:00.000Z",
        "quantity": 5,
        "expiration-date": "2015-06-15T04:00:00.000Z",
        "dispensed-date": "2014-07-14T04:00:00.000Z",
        "station-number": "12",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/776906",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/776906\/tracking"
      }
    },
    {
      "id": "1435528",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 1435528,
        "prescription-number": "3636039",
        "prescription-name": "Drug 9 And this drug has a longer name 0.25MG TAB",
        "refill-submit-date": "2016-04-26T04:00:00.000Z",
        "refill-date": "2016-04-11T04:00:00.000Z",
        "refill-remaining": 9,
        "facility-name": "SLC4",
        "ordered-date": "2016-03-27T04:00:00.000Z",
        "quantity": 10,
        "expiration-date": "2017-03-28T04:00:00.000Z",
        "dispensed-date": "2016-04-11T04:00:00.000Z",
        "station-number": "12",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435528",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435528\/tracking"
      }
    },
    {
      "id": "1435530",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 1435530,
        "prescription-number": "3636040",
        "prescription-name": "B 200MG TAB",
        "refill-submit-date": "2016-04-26T04:00:00.000Z",
        "refill-date": "2016-04-11T04:00:00.000Z",
        "refill-remaining": 9,
        "facility-name": "SLC4",
        "ordered-date": "2016-03-29T04:00:00.000Z",
        "quantity": 10,
        "expiration-date": "2017-03-30T04:00:00.000Z",
        "dispensed-date": "2016-04-11T04:00:00.000Z",
        "station-number": "12",
        "is-refillable": false,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435530",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435530\/tracking"
      }
    }
  ],
  "links": {
    "self": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions?",
    "first": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions?page=1&per_page=10",
    "prev": null,
    "next": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions?page=2&per_page=10",
    "last": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions?page=2&per_page=10"
  },
  "meta": {
    "updated-at": "Thu, 26 May 2016 12:42:21 EDT",
    "failed-station-list": "",
    "sort": {
      "refill-date": "ASC"
    },
    "pagination": {
      "current-page": 1,
      "per-page": 10,
      "total-pages": 2,
      "total-entries": 14
    }
  }
}
```
