# Education Form Serialization & Submission

* A series of Spool Files are created with applications grouped into regions
  * The files are created from individual applications stored in the database for a given day
  * The applications are stored in a format that matches vets-json-schema/dist/edu-benefits-schema.json
  * The applications are formatted and concatinated according to the 22-1990.erb template
  * The file must use windows-style newlines, and have a maximum line length of 78 characters before the newlines

* The generated files are SFTPed to a remote system or systems.
