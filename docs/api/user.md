# GET /v0/user
Gets all data associated to a User.

## Required Parameters
`Authorization: Token token=abcd1234...`

## Example
### Request
```
GET http://api.vets.gov/v0/user HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
Authorization: Token token=RiW_3isZHtUszCLvEAv4vEyCV37K8yFeezQm4fdT
```

### Response
```javascript
{
  "data": {
    "id": "",
    "type": "users",
    "attributes": {
      // possible values: [facilities, hca, edu-benefits, rx, messaging, disability-benefits, user-profile]
      "services": [
        "facilities",
        "hca",
        "edu-benefits",
        "user-profile"
      ],
      "profile": {
        // guaranteed not-null @ LOA 1
        "email": "william.ryan@gmail.com",
        // guaranteed not-null @ LOA 2 & higher
        "first_name": "WILLIAM",
        "middle_name": "P",
        "last_name": "RYAN",
        "birth_date": "1937-03-07",
        "loa": {
          "current": 3,
          "highest": 3
        },
        // these are never guaranteed
        "gender": "M",
        "zip": "01975",
        "last_signed_in": "2016-11-18T15:43:52.746Z"
      }
      "va_profile": {
        "birth_date": "19370307"
        "family_name": "RYAN",
        "gender": "M",
        "given_names": ["WILLIAM","P"],
        "status": "OK", // possible values [OK, NOT_FOUND, SERVER_ERROR]
        "active_status": null // possible values [active, new]
      }
    }
  }
}
```
