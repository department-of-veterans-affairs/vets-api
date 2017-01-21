# Vets.gov Health Records API

### API for Blue Button info from My HealtheVet

 Allows for generating and downloading a veteran's health records

##### Available routes

| Resource  | Description | Params |
| --------- | ----------- | ------ |
| GET /health_records/[refresh](health_records/refresh.md) | Triggers the daily PHR refresh job, 12-15 minutes delay in updating health record data. | N/A |
| GET /health_records/[eligible_data_classes](health_records/eligible_data_classes.md) | Returns the list of data classes that can be selected for generating a report | N/A |
| POST /health_records | Generates the report | Triggers a call to generate the health record | from_date, to_date, data_classes (all are required) |
| GET /health_records | Returns a health record | doctype: pdf/txt (must be bone of 'pdf or test' - defaults to pdf) |

##### Supported Formats
* JSON

##### Errors

| HTTP Code   | MHV Code | Description |
| ------------| -------- | ----------- |
| 400 | BB101 | MHV application authentication failed |
| 400 | BB102 | MHV application authorization failed |
| 400 | BB103 | Invalid MHV user credentials |
| 400 | BB104 | Missing MHV User credentials |
| 400 | BB105 | MHV user was not found |
| 400 | BB106 | MHV user is not eligible because they are blocked |
| 400 | BB107 | MHV system unable to create session token |
| 400 | BB108 | Missing MHV session token |
| 400 | BB109 | Invalid MHV session token |
| 400 | BB110 | Expired MHV session token |
| 400 | BB111 | Invalid MHV user permissions |
| 400 | BB132 | Missing MHV application token |
| 400 | BB135 | MHV user is not eligible because they have not accepted terms and conditions or opted-in |
| 400 | BB901 | MHV authentication service error |  
