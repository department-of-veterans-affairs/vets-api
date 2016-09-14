# V0 Secure Messaging for Healthcare API (SMAPI)

## Purpose
Securing Messaging within vets.gov enables secure, non-emergency, communications between veterans and their VA healthcare providers. The API provides basic messaging backend services for front-end consumers. As the API is currently under development, veteran authentication services are not provided, but a test veteran account has been created to allow SMAPI consumers to continue development.

### Currently Supported Services
At the present time SMAPI provides
* A list of Triage Team members for each veteran,
* Assigned folder information, either singly or as a list, for each veteran,
* A paginated list of messages on a folder by folder basis, details of an individual message, the ability to send messages, and the ability to save and send drafts, and the ability to view a message thread.

#### Triage Team Support
Triage teams review and control all mail, and process actions which can be completed without a claims folder. They represent the primary *recipients* with which the veteran can communicate. The applicable triage team properties returned by any triage team call:
* triage_team_id: The *id* corresponds to the *recipient_id* used in a secure message.
* name: The *name* of the triage team.
* relationType: The relation between the veteran and the triage team.

##### Getting a Triage Team List.
To get a list of all triage teams assigned to the veteran the following HTTP VERB and URL are used:
```
GET /v0/messaging/health/recipients
```
An example response would be:
```
{"data":[{"id":"585968","type":"va_healthcare_messaging_triage_teams","attributes":{"triage_team_id":585968,"name":"Triage group 311070 test 1","relation_type":"PATIENT"}},{"id":"585986","type":"va_healthcare_messaging_triage_teams","attributes":{"triage_team_id":585986,"name":"Triage group 311070 test 2","relation_type":"PATIENT"}},{"id":"613586","type":"va_healthcare_messaging_triage_teams","attributes":{"triage_team_id":613586,"name":"Vets.gov Testing_DAYT29","relation_type":"PATIENT"}}]}
```
#### Folder Support
Todo
#### Message Support
Todo
## Route Table
Todo
