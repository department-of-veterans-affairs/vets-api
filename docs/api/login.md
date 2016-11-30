# Authentication
The API's involved with log in and out.  Many API's require an auth token to use them.  The following API's list how to acquire and destry an auth token.


# APIs
| Http Verb | Path                 | Parameters                                              | Response                                        | Description                                                                   |
|-----------|----------------------|---------------------------------------------------------|-------------------------------------------------|-------------------------------------------------------------------------------|
| GET       | /v0/sessions/new     | url query param `level` possible values 1, 3            | `{"authenticat_via_vet": "\<ID.ME AUTH URL\>"}` | Gets an ID.me auth url at the specified level of assurance                   |
| DELETE    | /v0/sessions         | request header `Authorization: Token token=abcd1234...` | `{"logout_va_get": "\<ID.ME LOGOUT URL\>"`      | Gets an ID.me single logout url that may be used to destroy the vets.gov & ID.me sessions |

## Examples
#### Request
```
GET /v0/sessions/new?level=3 HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
```
<sub><sup>**Note** An invalid value of `level` will default to `level=1`.</sup></sub>
#### Response
```javascript
{
  "authenticate_via_get": "https://api.idmelabs.com/saml/SingleSignOnService?SAMLRequest=fVLBjtowEP2V3HxKHAfIUosgIdBKSLvbCtoe9lINzgBWHTvrcSj9%2BzoBVhy6e7PG772ZeW9mBI1p5aILR7vBtw4pJAsi9EE7u3SWugb9Fv1JK%2FyxearYMYRWcm6cAnN0FOQoz3MOkc97KR7LZgfqN0tWUUtb6IUuNIo8aHklqhTrrmQttoeDG71wX6112YsWa8q9ksVxQjLB0gnalyn44fpNIVS7dNx%2FWWym4i8xFEPJepwbSmADRUrclGmQqRi%2Bl2UclTIsXhlyU%2F0NIxSZDlLzo2xJPvmFeu8lQ5Ik7TQIMmg5Hbx%2FCQjUMLNi3tK%2Bzmn9S445Qybz3q0HKbz8%2F6d%2BjY7YaCDO2XvFs74PWx2SeQlyq5X35zR6m%2ByMMb9WXqEgBULvosrPzrfQPh4EJGJoaLrdD9AZWepRaX3GmvGb22umWM9XEAMPOA5JEvXtOA19XbhGVS4rXKPWppozgb38%2BtJxFjBwgEbtCGLC3JLPCI6D1ZhPBjg4rrpf1Uufx9M9P57f6jzfw%3D%3D&SigAlg=http%3A%2F%2Fwww.w3.org%2F2000%2F09%2Fxmldsig%23rsa-sha1&Signature=f6uC45r87dy%2FfuZUq%2BpyJFwylXc2ezUnxL8HQW6vm9QLQuZ9cOObtjK5rZHYfzGh38n%2FScMRIsjblJRpO94T4FOnYRAsQaw1dO1hc%2BOkEblxDksim2zrnd1vuJshLSvCJ9Ps0DLw7f1TUm8ngDu%2FK6Qv%2FMKs%2FMVeFIKGtIj02HLVn3BqnuASwnFhjGEaAm6ZQOsWGnqif3yCnYLxNbnxtibOYSsXOz3UKBI2PVa5BfAE26qyNyFaYUTzKf8D2JU5NSy5jaAJpYdyadpcWYYq2vB7AIyTaI6gIHCkGHM96S6OA895Q4hiSYRdfokjwFFMzXuL4wOAwNydaFGHFrAVDg%3D%3D"
}
```

#### Request
```
DELETE /v0/sessions HTTP/1.1
Host: www.vets.gov
Content-Type: application/json
Authorization: Token token=RiW_3isZHtUszCLvEAv4vEQCV37K8yFeezQm4fdT
```
#### Response
```javascript
{
  "logout_via_get": "https://api.idmelabs.com/saml/SingleLogoutService?SAMLRequest=fZHPa8MgFMf%2Fldw8mUSbZI00gUEZFLod1rHDLsWoaQWjzmfK%2Fvzlxw5lsF3k%2Bfh8%2FD55O%2BCD8ezoLm6Mr%2BpzVBCT%2FXRoy6N2tkHXGD2wLONep1oOyvAOUuGGbDazk7YXo1b9pMJNC4WSw75troqWtRljztaCFz0G4o72deYUlrKvtqSTd1NKMCoDhYit7FBNCcVJgST7RupGHlgBf1AybsKsIxC0xwlX4OxwObwBo3BMsdBA7N8UMCiYKfH5yObQMYBVJi%2FcK%2F4%2Fx0fXHTCGdTuZpot04V2rnHw6U1FuLhbapzg5uog7rJ7bHVeplcP%2B%2BTJhYHHv%2BNISpaOlrhfUDZa8EroXiuJWkIkJaLu%2BqKqClrmNe84zUXBS1lu8kr%2BJK9h7Xr7tcb2Gw%3D%3D&RelayState=92f-TJk7rzkFgqvdrccy75oJ1dzvzKw7e34nQUEu&SigAlg=http%3A%2F%2Fwww.w3.org%2F2000%2F09%2Fxmldsig%23rsa-sha1&Signature=m%2FO7AYJKbavOxKxmXhPEFitUkozuanPzHoiPx9an9isbwlCGUv6%2B7z85R%2BwIUPmTE6bcnLCADcR47iUVDE84%2FWGtajeBBL4GS7Gq3Jemb2w0NmZTTx5EWvZaDydnvfs%2FzQP%2FJCQ0f5At13yUSeQwafmZNAJQHshyCrgAN7J47cnD4BXMIefvSB9Jl4YiUmA6LHlHNUa3JH0s%2FtUdscKUFtHM%2B0rnSBq%2Bi4Rd0lakEV6n3pcKrHVZAQCikDZGhE7yUAV8ZZxJ23B32SJlReVI%2B2dXFM2EpopL86JMJVOlSC3WR5LE6NQE29YlxZ%2BIekCH1m03Na0DvzYP9wpqb%2FSolQ%3D%3D"
}
```
