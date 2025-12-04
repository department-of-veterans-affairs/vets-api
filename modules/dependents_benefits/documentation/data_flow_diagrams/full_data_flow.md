# Full Data Flow Documentation

Complete data flow for dependents benefits claims processing from submission to completion.

## Overview

Simplified end-to-end diagram showing happy path and failure branches. Click links below for detailed flows.

## Simplified End-to-End Flow

```mermaid
graph TD
    Start[User Submits Form] --> SaveClaim[Save Claim + User Data]
    SaveClaim --> DB1[(SavedClaim<br/>SavedClaimGroup parent)]
    DB1 --> GenChildren[Generate Child Claims<br/>686c and/or 674s]
    GenChildren --> DB2[(SavedClaim children<br/>SavedClaimGroup links)]
    DB2 --> Return[Return 200]
    
    Return --> BGSProc[BGSProcJob<br/>Select EP codes]
    BGSProc --> DB3[(BGS::Submission<br/>BGS::SubmissionAttempt)]
    DB3 --> BGSService[BGSV2<br/>create_proc + proc_forms]
    BGSService -->|Failure| BGSFail[Mark Failed]
    BGSService --> EnqueueSubs[Enqueue Jobs<br/>with EP codes<br/>0-1 pair 686c<br/>0-n pairs 674]
    
    EnqueueSubs --> SubmitAll[Submit Parallel<br/>BGS + Lighthouse]
    SubmitAll --> DB4[(Form Submissions<br/>+ Attempts)]
    DB4 --> Services[BGSV2 Form686c/674<br/>Lighthouse Benefits Intake]
    Services -->|Permanent Failure| SubFail[Mark Failed]
    Services --> Coordinate[Coordinate<br/>Check siblings]
    
    Coordinate --> MarkSuccess[Groups: SUCCESS<br/>Send Confirmation]
    
    BGSFail --> Backup[DependentBackupJob]
    SubFail --> Backup
    Backup --> DB5[(Lighthouse::Submission<br/>+ Attempt)]
    DB5 --> BackupService[Lighthouse<br/>Benefits Intake]
    BackupService -->|Failure| BackupFail[Failure Email<br/>End]
    BackupService --> BackupSuccess[Group: PROCESSING<br/>In-Progress Email]
    
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

1. **[Controller Flow](./controller_flow.md)** - Form submission through job enqueue
   - SavedClaim, SavedClaimGroup (parent + children)
   - Claim686cGenerator, Claim674Generator
   - Validation

2. **[UserData Collection](./userdata_flow.md)** - User data collection with fallbacks
   - Sources: User object, claim data, VA Profile, BGS
   - Encrypted storage in SavedClaimGroup

3. **[BGS Proc Job](./bgs_proc_job_flow.md)** - Creates vnp_proc + selects EP codes
   - BGS::Submission, BGS::SubmissionAttempt
   - BGSV2 create_proc, create_proc_form
   - 16 retries → backup job

4. **[Submission Jobs](./submission_jobs_flow.md)** - Parallel BGS + Lighthouse jobs
   - 0-1 pair 686c, 0-n pairs 674
   - BGS jobs use EP codes
   - Coordination with pessimistic locking

5. **[Backup Job](./backup_job_flow.md)** - Lighthouse-only fallback
   - Lighthouse::Submission + Attempt
   - PDF generation + stamping
   - Last resort, no further backup
