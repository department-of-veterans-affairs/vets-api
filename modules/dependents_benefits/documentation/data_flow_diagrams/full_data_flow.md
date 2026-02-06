# Full Data Flow Documentation

This document describes the complete data flow for dependents benefits claims processing from the controller through completion.

## Overview

This simplified end-to-end diagram shows the complete happy path from form submission to completion, with failure paths branching off to the side. Click the links below to zoom into detailed flow diagrams for each step.

## Simplified End-to-End Flow

```mermaid
graph TD
    Start[User Submits Form] --> SaveClaim[Save PrimaryDependencyClaim & User Data]
    SaveClaim --> DB1[(DB: SavedClaim<br/>SavedClaimGroup parent)]
    DB1 --> GenChildren[Generate Child Claims<br/>AddRemoveDependent and/or<br/>SchoolAttendanceApproval SavedClaims]
    GenChildren --> DB2[(DB: SavedClaim children<br/>SavedClaimGroup links)]
    DB2 --> Enqueue[ClaimProcessor.enqueue_submissions<br/>Enqueues jobs + sends submitted notification]
    Enqueue --> Return[Return 200 to User]
    
    Return -.Async.-> ParallelJobs[2 Parallel Jobs:<br/>BGSFormJob + ClaimsEvidenceFormJob]
    ParallelJobs --> DB3[(DB: BGS::Submission<br/>BGS::SubmissionAttempt<br/>ClaimsEvidenceApi::Submission<br/>ClaimsEvidenceApi::SubmissionAttempt)]
    
    DB3 --> BGSFlow[BGSFormJob:<br/>Generate proc_id<br/>Submit all child claims to BGS]
    DB3 --> ClaimsFlow[ClaimsEvidenceFormJob:<br/>Submit all child claims to<br/>Lighthouse Benefits Intake]
    
    BGSFlow --> BGSService[Service: BGS<br/>Form686c/Form674.submit]
    ClaimsFlow --> ClaimsService[Service: Claims Evidence API<br/>Upload PDFs to Lighthouse]
    
    BGSService -->|Any Permanent Failure| JobFail[Mark Parent Group FAILED]
    ClaimsService -->|Any Permanent Failure| JobFail
    
    BGSService --> Coordinate[Coordinate Success<br/>Check all child claims completed]
    ClaimsService --> Coordinate
    
    Coordinate --> MarkSuccess[Mark Parent Group SUCCESS<br/>Send Confirmation Email]
    
    JobFail --> Backup[DependentBackupJob]
    Backup --> DB5[(DB: Lighthouse::Submission<br/>Lighthouse::SubmissionAttempt)]
    DB5 --> BackupService[Service: Lighthouse<br/>Benefits Intake API<br/>Submit all child claims as package]
    BackupService -->|Failure| BackupFail[Send Error Notification<br/>End]
    BackupService --> BackupSuccess[Mark Parent Group PROCESSING]
    
    %% Styling
    classDef mainPath fill:#c8e6c9,stroke:#1b5e20,stroke-width:3px
    classDef database fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef service fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef failure fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    classDef backup fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    
    class Start,SaveClaim,GenChildren,Enqueue,Return,ParallelJobs,BGSFlow,ClaimsFlow,Coordinate,MarkSuccess,BackupSuccess mainPath
    class DB1,DB2,DB3,DB5 database
    class BGSService,ClaimsService,BackupService service
    class JobFail,BackupFail failure
    class Backup backup
```

## Detailed Flow Diagrams

Each step in the simplified diagram above has a detailed flow diagram:

1. **[Controller Flow](./controller_flow.md)** - Complete controller flow from form submission through async job enqueue
   - Database: SavedClaim (PrimaryDependencyClaim), SavedClaimGroup (parent and children)
   - Generators: Claim686cGenerator (creates AddRemoveDependent), Claim674Generator (creates SchoolAttendanceApproval)
   - ClaimProcessor.enqueue_submissions enqueues BGSFormJob and ClaimsEvidenceFormJob
   - Validation and error handling

2. **[UserData Collection](./userdata_flow.md)** - How user data is collected with fallback strategies
   - Data sources: User object, claim data, VA Profile, BGS
   - Fallback chains for each field
   - Error handling

3. **[Submission Jobs](./submission_jobs_flow.md)** - Two parallel jobs that each process all child claims
   - **BGSFormJob**: Generates proc_id, then submits all child claims (686c and/or 674s) to BGS
   - **ClaimsEvidenceFormJob**: Submits all child claims (686c and/or 674s) to Lighthouse Benefits Intake
   - Database: BGS::Submission, BGS::SubmissionAttempt, ClaimsEvidenceApi::Submission, ClaimsEvidenceApi::SubmissionAttempt
   - Services: BGS::Form686c/Form674.submit, ClaimsEvidenceApi::Uploader
   - Coordination patterns for success and failure
   - Pessimistic locking for claim completion coordination

4. **[Backup Job](./backup_job_flow.md)** - Lighthouse-only submission as last resort
   - Triggered when primary jobs fail permanently or exhaust retries
   - Database: Lighthouse::Submission, Lighthouse::SubmissionAttempt
   - Services: Lighthouse Benefits Intake API
   - Processes all child claims together as a package
   - PDF generation, stamping with VA.GOV and FDC Reviewed marks
   - Success: Mark parent group PROCESSING (submitted notification already sent by controller)
   - Failure: Send error notification, log to monitoring
