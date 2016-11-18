# /prescriptions/:id

##### Example query

GET prescriptions/1435525

##### Example response

```javascript
< HTTP/1.1 200 OK
< X-Frame-Options: SAMEORIGIN
< X-XSS-Protection: 1; mode=block
< X-Content-Type-Options: nosniff
< Content-Type: application/json; charset=utf-8
< Vary: Accept-Encoding
< ETag: W/"4255f8a8c15699197a33c44c23f6ab56"
< Cache-Control: max-age=0, private, must-revalidate
< X-Request-Id: 5715220fd1db40bf9c8cfdb37329c12f
< X-Runtime: 0.077863
< Transfer-Encoding: chunked
{
  "data": {
    "id": "1435525",
    "type": "va-rx-prescriptions",
    "attributes": {
      "prescription-id": 1435525,
      "prescription-number": "2719324",
      "prescription-name": "Drug 1 250MG TAB",
      "refill-submit-date": "2016-04-26T04:00:00.000Z",
      "refill-date": "2016-04-21T04:00:00.000Z",
      "refill-remaining": 9,
      "facility-name": "ABC1223",
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
  "meta": {
    "updated-at": null,
    "failed-station-list": null
  }
}
```
