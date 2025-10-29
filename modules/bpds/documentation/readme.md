# Documentation



## ADRs

| Path | Description |
|------|-------------|
| `modules/bpds/documentation/adr/0001-record-architecture-decisions.md` | Establishes the use of Architecture Decision Records (ADRs) for documenting architectural decisions made on the BPDS project |
| `modules/bpds/documentation/adr/0002-initial-research-and-findings.md` | Documents initial research on BPDS endpoint specs, JSON schema formatting, and decision to pursue BPDS API credentials despite unknowns |
| `modules/bpds/documentation/adr/0003-received-credentials.md` | Records receiving BPDS credentials for dev/test/staging environments and decision to implement custom JWT token generation |
| `modules/bpds/documentation/adr/0004-successfully-connected-to-bpds.md` | Documents successful connection to BPDS using JWT encoder and forward proxy via SSH tunneling, enabling POST/GET API calls |
| `modules/bpds/documentation/adr/0005-created-service-class.md` | Records implementation of BPDS service class for programmatic data submissions/retrievals and addition of feature flipper |
| `modules/bpds/documentation/adr/0006-db-schema-changes.md` | Documents database schema changes to support BPDS and Lighthouse form submissions, creating service-specific tables instead of shared ones |
| `modules/bpds/documentation/adr/0007-adding-new-submission-and-attempt-models.md` | Records creation of abstract submission/attempt model classes with data encryption for interacting with new database tables |
| `modules/bpds/documentation/adr/0008-adding-sidekiq-job.md` | Documents implementation of Sidekiq job for automatic BPDS submissions with retry logic, monitoring, and logging capabilities |
| `modules/bpds/documentation/adr/0009-adding-user-identifier-to-bpds-request.md` | Records logic for retrieving and encrypting user identifiers (participant ID or file number) to associate users with BPDS submissions |
