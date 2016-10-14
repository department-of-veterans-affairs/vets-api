# GET /profile
Gets all data associated to a User.

## Required Parameters
`Authorization: Token token=abcd1234...`

## Example
### Request
```
GET /v0/profile HTTP/1.1
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
      // guaranteed not-null @ LOA 1
      "services": ["service1", "service2"], // service names TBD
      "profile": {
        // guaranteed not-null @ LOA 1
        "email": "william.ryan@gmail.com",
        // guaranteed not-null @ LOA 2 & higher
        "first_name": "WILLIAM",
        "middle_name": "P",
        "last_name": "RYAN",
        "birth_date": "1937-03-07T05:00:00.000Z",
        "loa": {
          "current": 'loa1',
          "highest": '<duplicate current if empty>'
        }
        // these are never guaranteed
        "gender": null,
        "zip": null,
        "last_signed_in": null
      }
      "va_profile": {
        "birth_date": '19800101',
        "family_name": nil,
        "gender": 'M',
        "given_names": ['WILLIAM','RYAN'],
        "status": 'active'
      }
    }
  }
}
```

### Notes
- We need to let front-end know whether or not we have MVI data
- More specifically, we need to let front end know which systems are available based on MVI data.  Proposal:

   {services: ["service1", "service2"]}
