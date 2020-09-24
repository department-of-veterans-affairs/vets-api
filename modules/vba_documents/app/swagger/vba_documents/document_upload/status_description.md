Document upload status. Note that until a document status of
“received”, “processing”, or “success” is returned, a client
cannot consider the document as received by VA. In particular a
status of “uploaded” means that the document package has been
transmitted, but possibly not validated. Any errors with the
document package (unreadable PDF, etc) may cause the status to
change to “error”.

* `pending` - Initial status, indicates no document package has been uploaded yet
* `uploaded` - Indicates document package has been successfully uploaded (PUT) from the vendor's application system to the API server but has not yet been validated. Date of Receipt is _not_ yet established with this status.
* `received` - Indicates document package has been received upstream of the API, but is not yet in processing. <ins>Date of Receipt is set when this status is achieved.</ins> (This is also the final status in the sandbox environment unless further progress is simulated.)
* `processing` - Indicates VBA Intake, Conversion and Mail Handling Services (ICMHS) is processing the document package.
* `success` - Indicates document package has been received by Digital Mail Handling System (DHMS, aka the Centralized Mail portal).
* `error` - Indicates that there was an error. See the `code` and `message` for further information.
* `expired` - Indicates that the submission was not successfully uploaded via PUT request within the 15-minute window after the POST request. We recommend coding to retry unsuccessful uploads using the same GUID within 15 minutes in case of connection issues.
