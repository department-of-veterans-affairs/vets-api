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
  // guaranteed not-null @ LOA 1
  "uuid": "11d21c9bf46642509aba20c4a5d5306d",
  "email": "william.ryan@gmail.com",
  "loa_current": "loa1",

  // guaranteed not-null @ LOA 2
  "first_name": "WILLIAM",
  "middle_name": "P",
  "last_name": "RYAN",
  "birth_date": "1937-03-07T05:00:00.000Z",
  "ssn": "111223333",

  // never guaranteed
  "gender": null,
  "zip": null,
  "loa_highest": null,
  "last_signed_in": null,
  "edipi": null,
  "participant_id": null,
  "mvi": {
      "birth_date": '19800101',
      "edipi": '1234^NI^200DOD^USDOD^A',
      "vba_corp_id": '12345678^PI^200CORP^USVBA^A',
      "family_name": nil,
      "gender": 'M',
      "given_names": nil,
      "icn": '1000123456V123456^NI^200M^USVHA^P',
      "mhv_id": '123456^PI^200MHV^USVHA^A',
      "ssn": '111223333',
      "status": 'active'
  }
}
```
