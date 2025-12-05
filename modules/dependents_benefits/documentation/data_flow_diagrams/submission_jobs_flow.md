# Submission Jobs Flow

[← Back to Overview](./full_data_flow.md) | [← Back to BGS Proc Job](./bgs_proc_job_flow.md)

This diagram shows what happens when `ClaimProcessor.enqueue_submissions` is called with a `parent_claim_id` and `proc_id` after BGSProcJob succeeds. Jobs are enqueued in parallel based on which child claims exist: 0-1 pair for 686c forms (BGS686cJob + Claims686cJob) and 0-n pairs for 674 forms (one BGS674Job + Claims674Job per student).

```mermaid
graph TD
    Start[ClaimProcessor.enqueue_submissions<br/>parent_claim_id, proc_id] --> Split{Collect Child Claims}
    
    Split -.Async.-> Job686c[BGS686cJob#perform<br/>claim_id, proc_id]
    Split -.Async.-> JobClaims686c[Claims686cJob#perform<br/>claim_id, proc_id]
    Split -.Async.-> Job674[BGS674Job#perform<br/>claim_id, proc_id]
    Split -.Async.-> JobClaims674[Claims674Job#perform<br/>claim_id, proc_id]
    
    %% BGS686cJob Flow with detailed subgraphs
    Job686c --> Check686c{Parent Group<br/>Failed?}
    Check686c -->|Yes| Skip686c[Early Exit]
    Check686c -->|No| DB686c1[(DB: BGSFormSubmission<br/>find_or_create)]
    DB686c1 --> DB686c2[(DB: BGSFormSubmissionAttempt<br/>create)]
    DB686c2 --> Submit686c[Call BGSV2::Form686c.submit<br/>Creates vnp_veteran, relationships,<br/>vnp_benefit_claim, BenefitClaim]
    Submit686c --> Success686c{Success?}
    
    %% Success Coordination Subgraph for BGS686cJob
    subgraph SuccessFlow686c[Success Coordination Pattern]
        Update686cSuccess[Update Attempt & Submission<br/>status: success]
        Update686cSuccess --> CheckSiblings686c{All Current<br/>Group Succeeded?}
        CheckSiblings686c -->|Yes| MarkGroup686c[Mark SavedClaimGroup<br/>current: SUCCESS]
        CheckSiblings686c -->|No| Wait686c[Wait for Siblings]
        MarkGroup686c --> CheckAll686c{All Child<br/>Groups Succeeded?}
        CheckAll686c -->|Yes| Final686c[Mark Parent: SUCCESS<br/>Send Confirmation Email]
        CheckAll686c -->|No| Done686c[Job Complete]
    end
    
    Success686c -->|Yes| Update686cSuccess
    
    %% Failure Coordination Subgraph for BGS686cJob
    subgraph FailureFlow686c[Failure Coordination Pattern]
        UpdateFailed686c[Update SubmissionAttempt<br/>status: failed]
        UpdateFailed686c --> PermFailure686c{Permanent<br/>Failure?}
        PermFailure686c -->|Yes| MarkFailed686c[Mark Groups FAILED<br/>current & parent SavedClaimGroups]
        PermFailure686c -->|No| Retry686c{Retries<br/>< 16?}
        Retry686c -->|Yes| RetryJob686c[Sidekiq Retry<br/>Returns to Job Start]
        Retry686c -->|No| MarkFailed686c
        MarkFailed686c --> Backup686c[Trigger DependentBackupJob]
    end
    
    Success686c -->|No| UpdateFailed686c
    
    RetryJob686c -.Retry.-> Job686c
    
    %% Claims686cJob Flow (references patterns)
    JobClaims686c --> CheckClaims686c{Parent Group<br/>Failed?}
    CheckClaims686c -->|Yes| SkipClaims686c[Early Exit]
    CheckClaims686c -->|No| DBClaims686c1[(DB: LighthouseFormSubmission<br/>find_or_create)]
    DBClaims686c1 --> DBClaims686c2[(DB: LighthouseFormSubmissionAttempt<br/>create)]
    DBClaims686c2 --> SubmitClaims686c[Generate PDF<br/>Upload via Claims Evidence API<br/>Lighthouse Benefits Intake]
    SubmitClaims686c --> SuccessClaims686c{Success?}
    SuccessClaims686c -->|Yes| SuccessCoordClaims686c[Success Coordination<br/>Same as BGS686cJob]
    SuccessClaims686c -->|No| FailureCoordClaims686c[Failure Coordination<br/>Same as BGS686cJob]
    
    %% BGS674Job Flow (references patterns)
    Job674 --> Check674{Parent Group<br/>Failed?}
    Check674 -->|Yes| Skip674[Early Exit]
    Check674 -->|No| DB6741[(DB: BGSFormSubmission<br/>find_or_create)]
    DB6741 --> DB6742[(DB: BGSFormSubmissionAttempt<br/>create)]
    DB6742 --> Submit674[Call BGSV2::Form674.submit<br/>Creates school attendance records]
    Submit674 --> Success674{Success?}
    Success674 -->|Yes| SuccessCoord674[Success Coordination<br/>Same as BGS686cJob]
    Success674 -->|No| FailureCoord674[Failure Coordination<br/>Same as BGS686cJob]
    
    %% Claims674Job Flow (references patterns)
    JobClaims674 --> CheckClaims674{Parent Group<br/>Failed?}
    CheckClaims674 -->|Yes| SkipClaims674[Early Exit]
    CheckClaims674 -->|No| DBClaims6741[(DB: LighthouseFormSubmission<br/>find_or_create)]
    DBClaims6741 --> DBClaims6742[(DB: LighthouseFormSubmissionAttempt<br/>create)]
    DBClaims6742 --> SubmitClaims674[Generate PDF<br/>Upload via Claims Evidence API]
    SubmitClaims674 --> SuccessClaims674{Success?}
    SuccessClaims674 -->|Yes| SuccessCoordClaims674[Success Coordination<br/>Same as BGS686cJob]
    SuccessClaims674 -->|No| FailureCoordClaims674[Failure Coordination<br/>Same as BGS686cJob]
    
    %% Styling
    classDef trigger fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    classDef process fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px
    classDef database fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef service fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef decision fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef failure fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    classDef coordination fill:#e1bee7,stroke:#4a148c,stroke-width:2px
    
    class Start trigger
    class Job686c,JobClaims686c,Job674,JobClaims674,Update686cSuccess,UpdateFailed686c,MarkFailed686c,MarkGroup686c,Skip686c,SkipClaims686c,Skip674,SkipClaims674,Wait686c,Done686c,Final686c,RetryJob686c process
    class DB686c1,DB686c2,DBClaims686c1,DBClaims686c2,DB6741,DB6742,DBClaims6741,DBClaims6742 database
    class Submit686c,SubmitClaims686c,Submit674,SubmitClaims674 service
    class Split,Check686c,CheckClaims686c,Check674,CheckClaims674,Success686c,SuccessClaims686c,Success674,SuccessClaims674,Retry686c,CheckSiblings686c,CheckAll686c,PermFailure686c decision
    class Backup686c failure
    class SuccessCoordClaims686c,FailureCoordClaims686c,SuccessCoord674,FailureCoord674,SuccessCoordClaims674,FailureCoordClaims674 coordination
```

## Key Points

- **Conditional Job Creation**: Jobs only created for child claims that exist
  - **686c**: 0-1 BGS686cJob + 0-1 Claims686cJob (if 686c child claim exists)
  - **674**: 0-n BGS674Job + 0-n Claims674Job (one pair per 674 child claim/student)
- **Parallel Execution**: All created jobs run in parallel
- **Early Exit**: Jobs check parent group status before processing
- **Two Submission Types**:
  - **BGS Jobs**: Submit directly to BGSV2 service
  - **Claims Jobs**: Generate PDF and upload to Lighthouse Benefits Intake
- **Success Coordination**: Uses pessimistic locking to coordinate sibling completion
- **Failure Coordination**: Permanent failures or retry exhaustion trigger backup job

## Coordination Patterns

Both success and failure coordination patterns are shown in detail for BGS686cJob. The other three jobs follow the same patterns with service-specific differences.

## Next Steps

- **On Permanent Failure**: [Backup Job](./backup_job_flow.md) - Lighthouse-only submission as fallback
