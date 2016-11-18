# /prescriptions/active

##### Example query

GET prescriptions/active
GET prescriptions/active?page=1&per_page=10

##### Example response

```javascript
< HTTP/1.1 200 OK
< X-Frame-Options: SAMEORIGIN
< X-XSS-Protection: 1; mode=block
< X-Content-Type-Options: nosniff
< Content-Type: application/json; charset=utf-8
< Vary: Accept-Encoding
< ETag: W/"36b869567955f7e27af6973694358d8f"
< Cache-Control: max-age=0, private, must-revalidate
< X-Request-Id: 40e7000d3d3048f4958c6a0b7a8c7106
< X-Runtime: 0.136315
< Transfer-Encoding: chunked
< 
{
  "data": [
    {
      "id": "1435527",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 1435527,
        "prescription-number": "3636038",
        "prescription-name": "Drug 4 100MG TAB",
        "refill-submit-date": "2016-04-26T04:00:00.000Z",
        "refill-date": "2016-04-11T04:00:00.000Z",
        "refill-remaining": 9,
        "facility-name": "DEF5",
        "ordered-date": "2016-03-27T04:00:00.000Z",
        "quantity": 10,
        "expiration-date": "2017-03-28T04:00:00.000Z",
        "dispensed-date": "2016-04-11T04:00:00.000Z",
        "station-number": "23",
        "is-refillable": true,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435527",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435527\/tracking"
      }
    },
    {
      "id": "1435528",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 1435528,
        "prescription-number": "3636039",
        "prescription-name": "Drug 5 0.25MG TAB",
        "refill-submit-date": "2016-04-26T04:00:00.000Z",
        "refill-date": "2016-04-11T04:00:00.000Z",
        "refill-remaining": 9,
        "facility-name": "DEF5",
        "ordered-date": "2016-03-27T04:00:00.000Z",
        "quantity": 10,
        "expiration-date": "2017-03-28T04:00:00.000Z",
        "dispensed-date": "2016-04-11T04:00:00.000Z",
        "station-number": "23",
        "is-refillable": true,
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
        "prescription-name": "AMINOPHYLLINE 200MG TAB",
        "refill-submit-date": "2016-04-26T04:00:00.000Z",
        "refill-date": "2016-04-11T04:00:00.000Z",
        "refill-remaining": 9,
        "facility-name": "DEF5",
        "ordered-date": "2016-03-29T04:00:00.000Z",
        "quantity": 10,
        "expiration-date": "2017-03-30T04:00:00.000Z",
        "dispensed-date": "2016-04-11T04:00:00.000Z",
        "station-number": "23",
        "is-refillable": true,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435530",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435530\/tracking"
      }
    },
    {
      "id": "1435524",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 1435524,
        "prescription-number": "2719323",
        "prescription-name": "Drug 1 400MG TAB",
        "refill-submit-date": "2016-04-26T04:00:00.000Z",
        "refill-date": "2016-04-21T04:00:00.000Z",
        "refill-remaining": 9,
        "facility-name": "ABC123 This is a facility with a long name",
        "ordered-date": "2016-03-27T04:00:00.000Z",
        "quantity": 10,
        "expiration-date": "2017-03-28T04:00:00.000Z",
        "dispensed-date": "2016-04-21T04:00:00.000Z",
        "station-number": "23232323",
        "is-refillable": true,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435524",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435524\/tracking"
      }
    },
    {
      "id": "1435525",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 1435525,
        "prescription-number": "2719324",
        "prescription-name": "Drug 2 250MG TAB",
        "refill-submit-date": "2016-04-26T04:00:00.000Z",
        "refill-date": "2016-04-21T04:00:00.000Z",
        "refill-remaining": 9,
        "facility-name": "ABC123",
        "ordered-date": "2016-03-29T04:00:00.000Z",
        "quantity": 10,
        "expiration-date": "2017-03-30T04:00:00.000Z",
        "dispensed-date": "2016-04-21T04:00:00.000Z",
        "station-number": "23",
        "is-refillable": true,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435525",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435525\/tracking"
      }
    },
    {
      "id": "1435526",
      "type": "va-rx-prescriptions",
      "attributes": {
        "prescription-id": 1435526,
        "prescription-number": "2719325",
        "prescription-name": "Drug 3 with a longer name here 100MG TAB",
        "refill-submit-date": "2016-04-26T04:00:00.000Z",
        "refill-date": "2016-04-21T04:00:00.000Z",
        "refill-remaining": 9,
        "facility-name": "ABC123",
        "ordered-date": "2016-03-29T04:00:00.000Z",
        "quantity": 10,
        "expiration-date": "2017-03-30T04:00:00.000Z",
        "dispensed-date": "2016-04-21T04:00:00.000Z",
        "station-number": "23",
        "is-refillable": true,
        "is-trackable": false
      },
      "links": {
        "self": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435526",
        "tracking": "http:\/\/localhost:3000\/rx\/v1\/prescriptions\/1435526\/tracking"
      }
    }
  ],
  "links": {
    "self": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions\/active?",
    "first": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions\/active?page=1&per_page=10",
    "prev": null,
    "next": null,
    "last": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions\/active?page=1&per_page=10"
  },
  "meta": {
    "updated-at": "Thu, 26 May 2016 13:05:43 EDT",
    "failed-station-list": "",
    "sort": {
      "refill-date": "ASC"
    },
    "pagination": {
      "current-page": 1,
      "per-page": 10,
      "total-pages": 1,
      "total-entries": 6
    }
  }
}
```
