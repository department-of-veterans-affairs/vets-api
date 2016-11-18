# Vets.gov Prescriptions API

### API for prescription info from My HealtheVet

 Allows for the managing and tracking of Veterans' VA-issued prescriptions


##### Available routes

| Resource  | Description | Params |
| --------- | ----------- | ------ |
| GET [/prescriptions](prescriptions/prescriptions.md)  | Returns all VA prescriptions for the patient that are or were fillable online. Includes historical/inactive prescriptions. | <ul><li>refill_status: See chart below</li></ul> |
| GET [/prescriptions/:id](prescriptions/prescriptions-id.md)  | Returns a single VA prescription based on prescription id. | N/A |
| GET [/prescriptions/active](prescriptions/prescriptions-active.md)  | Returns all current VA prescriptions for the patient that are fillable online.  | N/A |
| PATCH [/prescriptions/:id/refill](prescriptions/prescriptions-id-refill.md)  | Submits a refill for the prescription ID provided.  | N/A |
| GET [/prescriptions/:prescription_id/trackings](prescriptions/prescriptions-prescription_id-tracking.md)  | Returns all the tracking information of the provided prescription as a collection.  | <ul><li>prescription_id: id of the prescription you want to obtain tracking info for <i>(Currently required)</i></li><li>id: the tracking id of the shipment <i>(Currently not supported)</i></li></ul> |

##### Supported Formats
* JSON

##### Pagination

GET requests that return more than one result will be paginated.  The default pagination returns the first 10 items in the collection.  In order to view subsequent items or to change the number of items being returned, you can specify the "page" and "per_page" parameters in your request.  "page" should be greater than 0 and "per_page" should be greater than 0 but less than or equal to 100.  If more than 100 items are requested per page, 100 will be returned.  "page" will always default to the first page unless otherwise specified.

In other words, append the following:
```javascript
?page=<something other than 1>&per_page=<something other than 10 but less than 100>
```

For example,
```javascript
GET prescriptions/active?page=2&per_page=20
```

Pagination data will be returned in the JSON response as follows:
```javascript
"meta": {
  "pagination": {
    "current-page": 1,
    "per-page": 10,
    "total-pages": 1,
    "total-entries": 6
  }
}
```

Links that can be used to display the pagination are also returned in the response:
```javascript
"links": {
  "self": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions?",
  "first": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions?page=1&per_page=10",
  "prev": null,
  "next": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions?page=2&per_page=10",
  "last": "http:\/\/ec2-52-90-149-185.compute-1.amazonaws.com:3004\/rx\/v1\/prescriptions?page=2&per_page=10"
},
```

Pagination uses the [will_paginate](https://github.com/mislav/will_paginate) library.

##### Sorting

Results can be sorted by attribute in either ascending or descending order.  To sort, pass in the attribute you want to sort by. By default, it will sort in ascending order; to sort in descending order negate the attribute.  The default attribute used is the prescription refill date.

```javascript
?sort=facility_name
?sort=-prescription_id
```

Sorting informtion is returned in the JSON response:

```javascript
"meta": {
  "sort": {
    "refill-date": "ASC"
  },
 }
```

##### Filtering

You can also filter the results list returned.  Right now, the only attribute supported is the refill status.  In a call to GET /prescriptions you can specify which refill status to use as a filter by passing it in as the "refill_status" parameter.

##### Errors

| HTTP Code  | MHV Code | Description |
| -----------| -------- | ----------- |
| 404 | N/A |Resource not found |
| 503 | N/A |Internal error |
| 400 | 99 | Unknown error |
| 400 | 101 | MHV application authentication failed |
| 400 | 102 | MHV application authorization failed |
| 400 | 103 | Invalid MHV user credentials |
| 400 | 104 | Missing MHV User credentials |
| 400 | 105 | MHV user was not found |
| 400 | 106 | MHV user is not eligible because they are blocked |
| 400 | 107 | MHV system unable to create session token |
| 400 | 108 | Missing MHV session token |
| 400 | 109 | Invalid MHV session token |
| 400 | 110 | Expired MHV session token |
| 400 | 111 | Invalid MHV user permissions |
| 400 | 117 | MHV Data integrity error |
| 400 | 132 | Missing MHV application token |
| 400 | 135 | MHV user is not eligible because they have not accepted terms and conditions or opted-in |
| 400 | 136 | The MHV user is not the owner of the prescription |
| 400 | 138 | Prescription not found |
| 400 | 139 | Prescription is not refillable |
| 400 | 140 | Prescription Refill was unsuccessful |
| 400 | 901 | MHV authentication service error |  


##### MHV Glossary of Prescription Status:
<i>These are the statuses that were surfaced to users on the MHV prototype; it looks like it may not match the list accepted by their API.  We will update when we get an answer on this.</i>

| Status	| Explanation |
| -------- | ----------- |
| Active | If you have refills, you may request a refill of this prescription from your VA pharmacy. |
| Pending | Your VA provider ordered this prescription. It may not be ready for pick up at the VA pharmacy window or to be mailed to you. Contact your VA pharmacy if you need this prescription now. |
| Suspense | You requested this prescription too early. It will be sent to you before you run out. Contact your VA pharmacy if you need this prescription now. |
| Hold | Call your VA pharmacy when you need more of this prescription. |
| Expired | This prescription is too old to fill. Call your VA healthcare team if you need more. (This does not refer to the expiration date of the medication in the bottle.) |
| Discontinued | Prescriptions your provider has discontinued and are no longer available to be sent to you or pick up at the VA pharmacy window Medications you do not get from a VA pharmacy that your provider recorded in your medical record. |
| Non-VA | Medications you do not get from a VA pharmacy that your provider recorded in your medical record. This includes medication prescribed by VA or non VA providers, over the counter medications, herbals, samples or other medications you take. |
| Remote Meds | Prescriptions you get from a different VA or the Department of Defense. |
