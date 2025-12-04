# Submission Jobs Flow

[← Back to Overview](./full_data_flow.md) | [← Back to BGS Proc Job](./bgs_proc_job_flow.md)

Shows what happens when `ClaimProcessor.enqueue_submissions` is called with `parent_claim_id`, `proc_id`, and `claim_type_end_products` after BGSProcJob succeeds. Jobs enqueued based on child claims: 0-1 pair for 686c, 0-n pairs for 674 (one per student).

```mermaid
graph TD
    Start[ClaimProcessor.enqueue_submissions<br/>parent_claim_id, proc_id, claim_type_end_products] --> Split{Collect Child Claims}
    
    Split -.Async.-> Job686c[BGS686cJob#perform<br/>claim_id, options<br/>proc_id, claim_type_end_product]
    Split -.Async.-> JobClaims686c[Claims686cJob#perform<br/>claim_id]
    Split -.Async.-> Job674[BGS674Job#perform<br/>claim_id, options<br/>proc_id, claim_type_end_product]
    Split -.Async.-> JobClaims674[Claims674Job#perform<br/>claim_id]
    
    %% BGS686cJob Flow
    Job686c --> Check686c{Parent Group<br/>Failed?}
    Check686c -->|Yes| Skip686c[Early Exit]
    Check686c -->|No| ValidateEP686c[Validate/Select EP Code<br/>from claim_type_end_products<br/>Query active claims]
    ValidateEP686c --> RecordEP686c[Record EP in<br/>SubmissionAttempt.metadata]
    RecordEP686c --> DB686c1[(BGSFormSubmission<br/>find_or_create)]
    DB686c1 --> DB686c2[(BGSFormSubmissionAttempt<br/>create)]
    DB686c2 --> Submit686c[BGSV2::Form686c.submit<br/>with EP code<br/>Creates benefit claim + relationships]
    Submit686c --> Success686c{Success?}
    
    %% Success Coordination
    subgraph SuccessFlow686c[Success Coordination]
        Update686cSuccess[Update Attempt: success]
        Update686cSuccess --> CheckSiblings686c{All Siblings<br/>Succeeded?}
        CheckSiblings686c -->|Yes| MarkGroup686c[Mark Current Group: SUCCESS]
        CheckSiblings686c -->|No| Wait686c[Wait]
        MarkGroup686c --> CheckAll686c{All Child<br/>Groups OK?}
        CheckAll686c -->|Yes| Final686c[Parent: SUCCESS<br/>Send Email]
        CheckAll686c -->|No| Done686c[Complete]
    end
    
    Success686c -->|Yes| Update686cSuccess
    
    %% Failure Coordination
    subgraph FailureFlow686c[Failure Coordination]
        UpdateFailed686c[Update Attempt: failed]
        UpdateFailed686c --> PermFailure686c{Permanent?<br/>Check BGS::Job::FILTERED_ERRORS}
        PermFailure686c -->|Yes| MarkFailed686c[Mark Groups: FAILED]
        PermFailure686c -->|No| Retry686c{Retries < 16?}
        Retry686c -->|Yes| RetryJob686c[Sidekiq Retry]
        Retry686c -->|No| MarkFailed686c
        MarkFailed686c --> Backup686c[DependentBackupJob]
    end
    
    Success686c -->|No| UpdateFailed686c
    
    RetryJob686c -.Retry.-> Job686c
    
    %% Claims686cJob Flow
    JobClaims686c --> CheckClaims686c{Parent Failed?}
    CheckClaims686c -->|Yes| SkipClaims686c[Exit]
    CheckClaims686c -->|No| DBClaims686c1[(LighthouseFormSubmission)]
    DBClaims686c1 --> DBClaims686c2[(LighthouseFormSubmissionAttempt)]
    DBClaims686c2 --> SubmitClaims686c[Generate PDF<br/>Upload to Lighthouse]
    SubmitClaims686c --> SuccessClaims686c{Success?}
    SuccessClaims686c -->|Yes| SuccessCoordClaims686c[Success Pattern<br/>Same as BGS686cJob]
    SuccessClaims686c -->|No| FailureCoordClaims686c[Failure Pattern<br/>Same as BGS686cJob]
    
    %% BGS674Job Flow
    Job674 --> Check674{Parent Failed?}
    Check674 -->|Yes| Skip674[Exit]
    Check674 -->|No| ValidateEP674[Validate/Select EP Code]
    ValidateEP674 --> RecordEP674[Record EP in metadata]
    RecordEP674 --> DB6741[(BGSFormSubmission)]
    DB6741 --> DB6742[(BGSFormSubmissionAttempt)]
    DB6742 --> Submit674[BGSV2::Form674.submit<br/>with EP code]
    Submit674 --> Success674{Success?}
    Success674 -->|Yes| SuccessCoord674[Success Pattern<br/>Same as BGS686cJob]
    Success674 -->|No| FailureCoord674[Failure Pattern<br/>Same as BGS686cJob]
    
    %% Claims674Job Flow
    JobClaims674 --> CheckClaims674{Parent Failed?}
    CheckClaims674 -->|Yes| SkipClaims674[Exit]
    CheckClaims674 -->|No| DBClaims6741[(LighthouseFormSubmission)]
    DBClaims6741 --> DBClaims6742[(LighthouseFormSubmissionAttempt)]
    DBClaims6742 --> SubmitClaims674[Generate PDF<br/>Upload to Lighthouse]
    SubmitClaims674 --> SuccessClaims674{Success?}
    SuccessClaims674 -->|Yes| SuccessCoordClaims674[Success Pattern<br/>Same as BGS686cJob]
    SuccessClaims674 -->|No| FailureCoordClaims674[Failure Pattern<br/>Same as BGS686cJob]
    
    %% Styling
    classDef trigger fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    classDef process fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px
    classDef database fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef service fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef decision fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef failure fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    classDef coordination fill:#e1bee7,stroke:#4a148c,stroke-width:2px
    classDef epcode fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    
    class Start trigger
    class Job686c,JobClaims686c,Job674,JobClaims674,Update686cSuccess,UpdateFailed686c,MarkFailed686c,MarkGroup686c,Skip686c,SkipClaims686c,Skip674,SkipClaims674,Wait686c,Done686c,Final686c,RetryJob686c process
    class DB686c1,DB686c2,DBClaims686c1,DBClaims686c2,DB6741,DB6742,DBClaims6741,DBClaims6742 database
    class Submit686c,SubmitClaims686c,Submit674,SubmitClaims674 service
    class Split,Check686c,CheckClaims686c,Check674,CheckClaims674,Success686c,SuccessClaims686c,Success674,SuccessClaims674,Retry686c,CheckSiblings686c,CheckAll686c,PermFailure686c decision
    class Backup686c failure
    class SuccessCoordClaims686c,FailureCoordClaims686c,SuccessCoord674,FailureCoord674,SuccessCoordClaims674,FailureCoordClaims674 coordination
    class ValidateEP686c,RecordEP686c,ValidateEP674,RecordEP674 epcode
```

## Key Points

- **EP Code Handling**: BGS jobs receive `claim_type_end_product` from BGSProcJob, validate/select from available codes, record in metadata
- **Conditional Jobs**: 0-1 pair for 686c, 0-n pairs for 674 (one per student)
- **Parallel Execution**: All jobs run in parallel
- **Early Exit**: Check parent group status before processing
- **Two Submission Types**:
  - **BGS Jobs**: Submit to BGSV2 with EP code
  - **Claims Jobs**: Generate PDF, upload to Lighthouse
- **Permanent Failure Detection**: BGS jobs check against `BGS::Job::FILTERED_ERRORS`
- **Coordination**: Pessimistic locking for sibling status checks
- **Retry/Backup**: 16 retries, then trigger backup job

## Next Steps

- **On Failure**: [Backup Job](./backup_job_flow.md) - Lighthouse-only fallback
