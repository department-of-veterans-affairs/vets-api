Unambiguous status code. Only present if status = "error"

* `DOC101` - Invalid multipart payload provided - not a multipart, or missing one or more required parts.
* `DOC102` - Invalid metadata - not parseable as JSON, incorrect fields, etc.
* `DOC103` - Invalid content - not parseable as PDF. Detail field will indicate which document or attachment part was affected.
* `DOC104` - Upload rejected by upstream system. Processing failed and upload must be resubmitted. Detail field will indicate nature of rejection.
* `DOC105` - Invalid or unknown id
* `DOC106` - File size limit exceeded. Each document may be a maximum of 100MB.
* `DOC107` - Empty payload.
* `DOC108` - Maximum dimensions exceeded. Height and width must be less than 78 in x 101 in.
* `DOC201` - Upload server error.
* `DOC202` - Error during processing by upstream system. Processing failed and upload must be resubmitted. Detail field will provide additional details where available.
