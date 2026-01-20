# Full Data Flow Documentation

This document describes the complete data flow for dependents benefits claims processing from the controller through completion.

## Overview

This simplified end-to-end diagram shows the complete happy path from form submission to completion, with failure paths branching off to the side. Click the links below to zoom into detailed flow diagrams for each step.

## Simplified End-to-End Flow

```mermaid
graph TD
    Start[User Submits Form] --> SaveClaim[Save Claim & User Data]
    SaveClaim --> DB1[(DB: SavedClaim<br/>SavedClaimGroup parent)]
    DB1 --> GenChildren[Generate Child Claims<br/>686c and/or 674 SavedClaims]
    GenChildren --> DB2[(DB: SavedClaim children<br/>SavedClaimGroup links)]
    DB2 --> Return[Return 200 to User]
    
    Return --> BGSProc[BGSProcJob]
    BGSProc --> DB3[(DB: BGS::Submission<br/>BGS::SubmissionAttempt)]
    DB3 --> BGSService[Service: BGSV2<br/>create_proc, create_proc_form]
    BGSService -->|Failure| BGSFail[Mark Failed]
    BGSService --> EnqueueSubs[Enqueue Submission Jobs<br/>0-1 BGS686c, 0-1 Claims686c<br/>0-n BGS674, 0-n Claims674<br/>per child claim]
    
    EnqueueSubs --> SubmitAll[Submit to Services<br/>Parallel execution]
    SubmitAll --> DB4[(DB: BGSFormSubmission<br/>LighthouseFormSubmission<br/>FormSubmissionAttempts)]
    DB4 --> Services[Services: BGSV2 Form686c/Form674<br/>Claims Evidence API]
    Services -->|Any Permanent Failure| SubFail[Mark Failed]
    Services --> Coordinate[Coordinate Success<br/>Check all siblings completed]
    
    Coordinate --> MarkSuccess[Mark All Groups SUCCESS<br/>Send Confirmation Email]
    
    BGSFail --> Backup[DependentBackupJob]
    SubFail --> Backup
    Backup --> DB5[(DB: Lighthouse::Submission<br/>Lighthouse::SubmissionAttempt)]
    DB5 --> BackupService[Service: Lighthouse<br/>Benefits Intake API]
    BackupService -->|Failure| BackupFail[Send Failure Email<br/>End]
    BackupService --> BackupSuccess[Mark PROCESSING<br/>Send In-Progress Email]
    
    %% Styling
    classDef mainPath fill:#c8e6c9,stroke:#1b5e20,stroke-width:3px
    classDef database fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef service fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef failure fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    classDef backup fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    
    class Start,SaveClaim,GenChildren,Return,BGSProc,EnqueueSubs,SubmitAll,Coordinate,MarkSuccess,BackupSuccess mainPath
    class DB1,DB2,DB3,DB4,DB5 database
    class BGSService,Services,BackupService service
    class BGSFail,SubFail,BackupFail failure
    class Backup backup
```

## Detailed Flow Diagrams

Each step in the simplified diagram above has a detailed flow diagram:

1. **[Controller Flow](./controller_flow.md)** - Complete controller flow from form submission through async job enqueue
   - Database: SavedClaim, SavedClaimGroup (parent and children)
   - Generators: Claim686cGenerator, Claim674Generator
   - Validation and error handling

2. **[UserData Collection](./userdata_flow.md)** - How user data is collected with fallback strategies
   - Data sources: User object, claim data, VA Profile, BGS
   - Fallback chains for each field
   - Error handling

3. **[BGS Proc Job](./bgs_proc_job_flow.md)** - BGSProcJob creates vnp_proc in BGS
   - Database: BGS::Submission, BGS::SubmissionAttempt
   - Services: BGSV2 create_proc, create_proc_form
   - Retry logic (up to 16 retries)
   - Success: Triggers submission jobs
   - Failure: Triggers backup job

4. **[Submission Jobs](./submission_jobs_flow.md)** - Parallel jobs submit to BGS and Lighthouse (one pair per child claim)
   - 0-1 BGS686cJob + 0-1 Claims686cJob (if 686c child claim exists)
   - 0-n BGS674Job + 0-n Claims674Job (one pair per 674 child claim)
   - Database: BGSFormSubmission, LighthouseFormSubmission, FormSubmissionAttempts
   - Services: BGSV2 Form686c/Form674, Claims Evidence
   - Coordination patterns for success and failure
   - Pessimistic locking for sibling coordination

5. **[Backup Job](./backup_job_flow.md)** - Lighthouse-only submission as last resort
   - Database: Lighthouse::Submission, Lighthouse::SubmissionAttempt
   - Services: Lighthouse Benefits Intake API
   - PDF generation and stamping
   - Success: Mark PROCESSING, send in-progress email
   - Failure: Send failure email, log to Datadog
