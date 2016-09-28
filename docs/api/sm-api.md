# Vets.gov Healthcare Messaging API

## API for secure messaging with My HealtheVet
Secure Messaging within vets.gov enables secure, non-emergency, communications between veterans and their VA healthcare providers.

### Available Routes
| Resource                                          | Description                         | Params                        |
| ------------------------------------------------- | ----------------------------------- | ------------------------------|
| GET /messaging/healthcare/recipients              | List possible recipients            | [Pagination](#pagination)     |
| GET /messaging/healthcare/folders                 | List folders                        | [Pagination](#pagination)     |
| GET /messaging/healthcare/folders/:id             | Returns a folder                    | None                          |
| POST /messaging/healthcare/folders                | Creates a folder                    | [json payload](#folder)  |
| DELETE /messaging/healthcare/folders/:id          | Deletes a folder                    | None                          |
| GET /messaging/health/folders/:folder_id/messages | List messages in folder             | None                          |
| GET /messaging/health/messages/:id                | Gets a message                      | None                          |
| GET /messaging/health/messages/:message_id/thread | List messages in thread             | [Pagination](#pagination)     |
| POST /messaging/health/messages                   | Sends a message.                    | [json payload](#message) |
| POST /messaging/health/message_drafts             | Creates a draft                     | [json draft payload](#draft-payload) |
| PUT /messaging/health/message_drafts/:id         | Updates a draft                     | [json draft payload](#draft-payload) |
| POST /messaging/health/messages/:id/reply | replies to a message | [json payload](#message) |

#### <a name="pagination"></a>Pagination Params
* **page:** The page number of the first message returned
* **per_page:** The number of messages in a returned page

#### <a name="folder"></a>Creating a Folder
Request:

`POST /messaging/healthcare/folders` with the following payload

```json
{
  "folder": {
    "name": "sample folder"
  }
}
```

Response

`STATUS: 201`

```json
{
  "data": {
    "id": "123123",
    "type": "folder",
    "attributes": {
      "folder_id": 123123,
      "name": "sample folder",
      "count": 0,
      "unread_count": 0,
      "system_folder": false
    },
    "links": {
      "self": "https:\/\/staging.vets.gov\/api\/v0\/messaging\/health\/folders\/123123"
    }
  }
}
```

#### <a name="message"></a>Creating a Message
Request:

`POST /messaging/health/messages` with the following payload

```json
{
  "message": {
    "category": "A category from the list of available categories",
    "subject": "Message Subject",
    "body": "The message body.",
    "recipient_id": 1
  }
}
```

Response

`STATUS: 201`

#### <a name="draft-payload"></a>Updating/Creating a Message Draft
Creating or updating a message draft require the same payload. For example,

Request:

`PUT /messaging/health/message_drafts/:id` with the following payload:

```json
{
  "message_draft": {
    "category": "A category from the list of available categories",
    "subject": "Message Subject",
    "body": "The message body.",
    "recipient_id": 1
  }
}
```

Response

`STATUS: 204`

```
  UPDATE THIS
```


### Supported Formats
<ul><li>JSON</li></ul>

### Resources

#### Triage teams
Triage teams review and control all mail, and process actions which can be completed without a claims folder. They represent the primary *recipients* with which the veteran can communicate. The *triage_team_id* is used as the *recipient_id* when sending a message or reply, or when creating a draft.

#### Folders
Information pertaining to folders can be retrieved for all folders in a list or individually. However, folder collections are not paginated.

#### Messages
Messages can be retrieved on a folder-by-folder basis. When bringing back messages from a folder, the results can either be paginated or contain the entire contents of the folder. In either case, returned messages do not contain body or attachment data. The default pagination returns all messages in the folder:
```
messaging/health/folders/:folder_id/messages
```
However, you may specify a desired pagination by populating the page and per_page parameters. The *page* parameter should be greater than 0 while the *per_page* parameter should be greater than 0 but less than or equal to 250. For example,
```
/messaging/health/folders/:folder_id/messages?page=1&per_page=50        // messages 0 - 49
/messaging/health/folders/:folder_id/messages?page=2&per_page=50        // messages 50 - 99
```
It is possible that the number of messages returned can be less than specified in the *per_page* parameter.

You may also set the *all* parameter to true, but doing so overrides *page* and *per_page* settings by returning all the messages in a folder. The following examples all return the entire set of messages in a folder:
```
/messaging/health/folders/:folder_id/messages
/messaging/health/folders/:folder_id/messages?all=true
/messaging/health/folders/:folder_id/messages?page=2&per_page=50&all=true
```
Pagination data will be returned in the JSON response, even in the case when all messages are requested. For example, the call to retrieve all the second page of 50 messages from an inbox containing 68 messages:
```
/messaging/health/folders/0/messages?page=2&per_page=50
```
returns
```
"meta": {
  folder_id: 0,
  current_page: 2,
  per_page: 50,
  count: 68
}
```
#### Links
TBD

#### Filtering
TBD

#### Sorting
TBD

### Errors and Response Codes

Error Codes And Responses
Each error response of 400 will result in the body containing an Error object.

| HTTP Code | MHV Code | Description |
| --------- | -------- | ----------- |
| 200  | - | Success |
| 400  | 99 | Unknown application error occurred |
| 400  | 100 | The message body cannot be blank |
| 400  | 101 | Application authentication failed |
| 400  | 102 | Application authorization failed |
| 400  | 103 | Invalid User Credentials |
| 400  | 104 | Missing User Credentials |
| 400  | 105 | User was not found |
| 400  | 106 | User is not eligible because they are blocked |
| 400  | 107 | System unable to create token |
| 400  | 108 | Missing session token |
| 400  | 109 | Invalid session token |
| 400  | 110 | Expired session token |
| 400  | 111 | Invalid user permissions (invalid user type for resource requested) |
| 400  | 112 | User is not owner of entity requested |
| 400  | 113 | Unable to read attachment |
| 400  | 114 | Unable to move message |
| 400  | 115 | Entity not found |
| 400  | 116 | The Folder must be empty before delete |
| 400  | 117 | A data integrity issue was encountered |
| 400  | 118 | It is not possible to move a message from the DRAFTS folder |
| 400  | 119 | Triage team does not exist |
| 400  | 120 | The Page Number must be greater than zero |
| 400  | 121 | The Page Size must be greater than zero |
| 400  | 122 | The attachment file type is currently not supported |
| 400  | 123 | The filename is a required parameter |
| 400  | 124 | The attachment file size exceeds the supported size limits |
| 400  | 125 | To create a folder the name is required |
| 400  | 126 | The folder already exists with the requested name |
| 400  | 127 | The folder name should only contain letters, numbers, and spaces |
| 400  | 128 | The message you are attempting to send is not a draft |
| 400  | 129 | Unable to reply because you are no longer associated with this Triage Team |
| 400  | 130 | Unable to reply because the source message is expired |
| 400  | 131 | Unable to reply to a message that is a draft |
| 400  | 132 | Missing application token |
| 400  | 133 | PageSize exceeds the maximum allowed limit |
| 400  | 134 | The message you are attempting to save is not a draft |
| 400  | 135 | User is not eligible because they have not accepted terms and conditions or opted-in |
| 400  | 900 | Mailbox Service Error |
| 400  | 901 | Authentication Service Error |
| 400  | 902 | Triage Group Service Error |
| 400  | 903 | Send Message Service Error |
| 400  | 904 | Message Service Error |
| 404  | - | Not Found: Unable to find resource being requested |
| 503  | - | Internal Error: Internal System Level Error |
