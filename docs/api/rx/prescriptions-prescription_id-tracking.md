# /prescriptions/:id/trackings

##### Example query

GET prescriptions/1435525/trackings

##### Example response

```javascript
< HTTP/1.1 200 OK
< X-Frame-Options: SAMEORIGIN
< X-XSS-Protection: 1; mode=block
< X-Content-Type-Options: nosniff
< Content-Type: application/json; charset=utf-8
< Vary: Accept-Encoding
< ETag: W/"0688d4c286bb05af0caa77a4ef80aadc"
< Cache-Control: max-age=0, private, must-revalidate
< X-Request-Id: 6c3b4c6796c648a99dbed633a1a94add
< X-Runtime: 0.064953
< Transfer-Encoding: chunked
{
  "data": [
    {
      "id": "01234567890",
      "type": "va-rx-trackings",
      "attributes": {
        "tracking-number": "01234567890",
        "prescription-id": 1435525,
        "prescription-number": "2719324",
        "prescription-name": "Drug 1 250MG TAB",
        "facility-name": "ABC123",
        "rx-info-phone-number": "(333)772-1111",
        "ndc-number": "12345678910",
        "shipped-date": "2016-04-21T04:00:00.000Z",
        "delivery-service": "UPS"
      },
      "links": {
        "self": "https://www.example.com/rx/v1/prescriptions/1435525/trackings",
        "prescription": "https://www.example.com/rx/v1/prescriptions/1435525",
        "tracking-url": "https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=01234567890"
      }
    },
    {
      "id": "54321612345",
      "type": "va-rx-trackings",
      "attributes": {
        "tracking-number": "54321612345",
        "prescription-id": 1435525,
        "prescription-number": "2719324",
        "prescription-name": "Drug 1 250MG TAB",
        "facility-name": "ABC123",
        "rx-info-phone-number": "(333)772-1111",
        "ndc-number": "12345678910",
        "shipped-date": "2016-04-11T04:00:00.000Z",
        "delivery-service": "UPS"
      },
      "links": {
        "self": "https://www.example.com/rx/v1/prescriptions/1435525/trackings",
        "prescription": "https://www.example.com/rx/v1/prescriptions/1435525",
        "tracking-url": "https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=54321612345"
      }
    }
  ],
  "links": {
    "self": "http://www.example.com/rx/v1/prescriptions/1435525/trackings?",
    "first": "http://www.example.com/rx/v1/prescriptions\/1435525/trackings?page=1&per_page=10",
    "prev": null,
    "next": null,
    "last": "http://www.example.com/rx/v1/prescriptions/1435525/trackings?page=1&per_page=10"
  },
  "meta": {
    "updated-at": "Wed, 27 Apr 2016 04:30:15 EDT",
    "failed-station-list": null,
    "sort": {
      "shipped-date": "DESC"
    },
    "pagination": {
      "current-page": 1,
      "per-page": 10,
      "total-pages": 1,
      "total-entries": 2
    }
  }
}
```
