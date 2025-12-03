# BGS Proc Job Flow

[← Back to Overview](./full_data_flow.md)

This diagram shows what happens inside `BGSProcJob#perform` after being triggered by `ClaimProcessor.create_proc_forms`.

```mermaid
graph TD
    Start[ClaimProcessor.create_proc_forms<br/>Triggers BGSProcJob] -.Async.-> Job[BGSProcJob#perform<br/>claim_id]
    
    Job --> CreateRecords[Create DB Records]
    CreateRecords --> DB1[(DB: BGS::Submission<br/>form_id: '686C-674'<br/>saved_claim_id)]
    DB1 --> DB2[(DB: BGS::SubmissionAttempt<br/>linked to Submission)]
    
    DB2 --> CallBGS[Call BGS Service<br/>BGSV2::Service.new]
    CallBGS --> CreateProc[create_proc<br/>proc_state: 'Started']
    CreateProc --> GetProcId[Get proc_id from response]
    
    GetProcId --> CreateForms[create_proc_form for each:<br/>- '21-686c' if submittable_686?<br/>- '21-674' if submittable_674?]
    
    CreateForms --> Success{Success?}
    
    Success -->|Yes| UpdateAttempt[Update BGS::SubmissionAttempt<br/>status: success]
    UpdateAttempt --> CallProcessor[ClaimProcessor.enqueue_submissions<br/>parent_claim_id, proc_id]
    CallProcessor -.Async.-> SubmissionJobs[Submission Jobs<br/>0-1 BGS686c, 0-1 Claims686c<br/>0-n BGS674, 0-n Claims674<br/>per child claim]
    CallProcessor --> Complete[Job Complete]
    
    Success -->|No - Transient Error| UpdateFailed[Update BGS::SubmissionAttempt<br/>status: failed<br/>error details]
    UpdateFailed --> Retry{Retry Count<br/>< 16?}
    Retry -->|Yes| RetryJob[Sidekiq Retry<br/>exponential backoff]
    RetryJob -.Retry.-> Job
    
    Retry -->|No| Exhausted[Retries Exhausted<br/>sidekiq_retries_exhausted callback]
    Exhausted --> HandlePerm[handle_permanent_failure]
    HandlePerm --> MarkFailed[Mark SavedClaimGroups<br/>current & parent as FAILED]
    MarkFailed --> BackupJob[Trigger DependentBackupJob<br/>Lighthouse submission]
    
    %% Styling
    classDef trigger fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    classDef process fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px
    classDef database fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef service fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef decision fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef failure fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    
    class Start,CallProcessor,SubmissionJobs trigger
    class Job,CreateRecords,GetProcId,UpdateAttempt,UpdateFailed,HandlePerm,MarkFailed,Complete,RetryJob,Exhausted process
    class DB1,DB2 database
    class CallBGS,CreateProc,CreateForms service
    class Success,Retry decision
    class BackupJob failure
```

## Key Points

- **BGS Service**: Creates vnp_proc and proc_form records in BGS
- **Database Tracking**: BGS::Submission and BGS::SubmissionAttempt track the operation
- **Retry Logic**: Up to 16 retries with exponential backoff for transient failures
- **Success Path**: Triggers submission jobs for actual form submission
- **Failure Path**: Triggers backup job after exhausting retries

## Next Steps

- **On Success**: [Submission Jobs](./submission_jobs_flow.md) - Four parallel jobs submit to BGS and Lighthouse
- **On Failure**: [Backup Job](./backup_job_flow.md) - Lighthouse-only submission as fallback
