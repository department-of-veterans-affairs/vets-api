# Vets.gov Healthcare Messaging API

## API for secure messaging with My HealtheVet
Secure Messaging within vets.gov enables secure, non-emergency, communications between veterans and their VA healthcare providers.

### Available Routes
| Resource                                          | Description                                       | Params                               |
| ------------------------------------------------- | ------------------------------------------------- | -------------------------------------|
| GET /messaging/healthcare/recipients              | List possible recipients                          | [Pagination](#pagination)            |
| GET /messaging/healthcare/folders                 | List folders                                      | [Pagination](#pagination)            |
| GET /messaging/healthcare/folders/:id             | Returns a folder                                  | None                                 |
| POST /messaging/healthcare/folders                | Creates a folder                                  | [json payload](#folder)              |
| DELETE /messaging/healthcare/folders/:id          | Deletes a folder                                  | None                                 |
| GET /messaging/health/folders/:folder_id/messages | List messages in folder                           | [Filtering](#filtering)              |
| GET /messaging/health/messages/:id                | Gets a message                                    | None                                 |
| GET /messaging/health/messages/:message_id/thread | List messages in thread                           | [Pagination](#pagination)            |
| POST /messaging/health/messages                   | Sends a message. [attachments](#attachments)      | [json payload](#message)             |
| POST /messaging/health/message_drafts             | Creates a draft                                   | [json draft payload](#draft-payload) |
| PUT /messaging/health/message_drafts/:id          | Updates a draft                                   | [json draft payload](#draft-payload) |
| POST /messaging/health/messages/:id/reply         | Replies to a message [attachments](#attachments)  | [json payload](#message)             |
| GET /messaging/health/messages/:message_id/attachments/:id | Gets an  attachment                      | Will immediately download the file   |

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

#### <a name="attachments"></a>Attachments
New Message and Reply Message support sending file attachments.

To send files, you need to use Content-Type of `'multipart/form-data'`
You must provide the message object as in url-encoded form data with the messages
object as usual, and provide an array of uploads outside of the messages object.

For whatever reason, MHV only provides the attachments that were created for the New Message
not for the Reply. This is something that will need to be discussed with MHV.

An Example Request:

```
Accept: application/json
Content-Type: multipart/form-data; boundary="----=_Part_7_22572641.1391727736568"
Content-Length: 1358
------=_Part_7_22572641.1391727736568
Content-Type: application/json; name=message
Content-Transfer-Encoding: binary
Content-Disposition: form-data; name="message"; filename="message"
{
"category": "MEDICATIONS",
"subject": "Send Msg via API with Attachment",
"body": "Test Send a Message to Grp",
"recipientId": 45961,
"recipientName": "TEST TRIAGE"
}
------=_Part_7_22572641.1391727736568
Content-Type: image/x-png; name=image1.png
Content-Transfer-Encoding: binary
Content-Disposition: form-data; name="uploads[]"; filename="image1.png"
‰PNG
------=_Part_7_22572641.1391727736568
Content-Type: image/x-png; name=image2.png
Content-Transfer-Encoding: binary
Content-Disposition: form-data; name="uploads[]"; filename="image2.png"
‰PNG
```

#### <a name="filtering"></a>Filtering
Filtering allows you to select a subset of messages in any folder. The call to list all messages is appended with query parameters that specify which attributes of a message you want to filter and one or more conditions to filter on.

The general format is:
```
/messaging/health/folders/:id/messages?filter[[attribute][comparison]]=value ...
```

For a given attribute, you can combine more than one filter conditions that are logically AND-ed. As an example, suppose you wish to filter all inbox (`:id=0`) messages to show only those messages that were sent between January 1, 2016 and January 31, 2016. The proper filter query for this would be:
```
?filter[[sent_date][gteq]]=2016-01-01T00:00:00
   &filter[[sent_date][lteq]]=2016-01-31T23:59:59
```
As another example, suppose you wish to filter all inbox (`:id=0`) messages to show only those messages that were sent on January 1, 2016.The proper filter query for this would be:
```
?filter[[sent_date][gteq]]=2016-01-01T00:00:00
   &filter[[sent_date][lteq]]=2016-01-01T23:59:59
```

Multiple attributes may be filtered at the same time, with the attribute conditions AND-ed together. For example, to show all inbox messages from "Smith, Bill" sent between January 1, 2016 and January 31, 2016:
```
?filter[[sent_date][gteq]]=2016-01-01T00:00:00
   &filter[[sent_date][lteq]]=2016-01-31T23:59:59
   &filter[[sender_name][eq]]=Smith,%20Bill
```

For a last example, to return all messages having the phrase "blood pressure" in the subject line:
```
?filter[[subject][match]]=blood%20pressure
```

The returned JSON contains metadata with the origin filter query parameters.

##### Permitted Comparisons
At the current time, filtering supports the following comparisons:

| Operator | Description |
| -------- | ----------- |
| eq       | Equality    |
| lteq     | Less than or equal to |
| gteq     | Greater than or equal to |
| not_eq   | Not equal |
| match    | Inexact match (case-insensitive substring match) |

#### Sorting
The query format to sort the results in an ascending order
```
?sort=field_name
```
Similarly, to sort the results in a descending order prefix the field name with `-`
```
?sort=-field_name
```

To sort on multiple fields, use the following syntax:
```
sort[]=field_name1&sort[]=field_name2
```

Sorting of result sets is available for:

| Resource | Fields | Default Sort |
| -------- | ------ | -------------|
| Messages | subject, sent_date, recipient_name, sender_name | sent_date (descending) |
| Prescriptions | prescription_name refill_status ordered_date facility_name | ordered_date (descending) |
| Trackings | shipped_date (descending) |
| Triage Teams | name (ascending) |

For example, to sort in ascending order all inbox messages on the sender's name:
```
?sort=sender_name
```
which returns
```
"meta": {
  "sort": {
    "sender_name": "ASC"
  }
}
```
To sort in descending order all inbox messages on the sender's name:
```
?sort=-sender_name
```
which returns
```
"meta": {
  "sort": {
    "sender_name": "DESC"
  }
}
```

To sort by descending `sent_date` followed by ascending `sender_name`:
```
sort[]=-sent_date&sort[]=sender_name
```
which returns
```
"meta":{
  "sort":{
    "sent_date":"DESC", "sender_name":"ASC"
  }
}
```

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
