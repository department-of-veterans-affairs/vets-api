Document upload status. Note that until a document status of
“received”, “processing”, or “success” is returned, a client
cannot consider the document as received by VA. In particular a
status of “uploaded” means that the document package has been
transmitted, but possibly not validated. Any errors with the
document package (unreadable PDF, etc) may cause the status to
change to “error”.

* `pending` - Initial status, indicates no document package has been uplaoded yet
* `uploaded` - Indicates document package has been successfully uploaded, but not yet processed or propagated to Central Mail API
* `received` - Indicates document package has been successfully propagated to Central Mail API
* `processing` - Indicates document package is being processed by ICMHS or a downstream system.
* `success` - Indicates document package has been received by DHMS.
* `error` - Indicates that there was an error. See the `code` and `message` for further information.
* `expired` - Indicates that the submission was not submitted in the 15 minute window of creation
