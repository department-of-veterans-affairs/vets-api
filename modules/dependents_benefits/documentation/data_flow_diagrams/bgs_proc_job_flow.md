# BGS Proc Job Flow

[← Back to Overview](./full_data_flow.md)

This diagram shows what happens inside `BGSProcJob#perform` after being triggered by `ClaimProcessor.create_proc_forms`.

```mermaid
graph TD
    Start[ClaimProcessor.create_proc_forms<br/>Triggers BGSProcJob] -.Async.-> Job[BGSProcJob#perform<br/>claim_id]
    
    Job --> CreateRecords[Create DB Records]
    CreateRecords --> DB1[(DB: BGS::Submission<br/>form_id: '686C-674'<br/>saved_claim_id)]
    DB1 --> DB2[(DB: BGS::SubmissionAttempt<br/>linked to Submission)]
    
    DB2 --> GetEPCodes[Get Available EP Codes<br/>Query active BGS claims<br/>Query pending sibling attempts<br/>Select from possible ep codes]
    GetEPCodes --> CallBGS[Call BGS Service<br/>BGSV2::Service.new]
    CallBGS --> CreateProc[create_proc<br/>proc_state: 'Started']
    CreateProc --> GetProcId[Get proc_id from response]
    
    GetProcId --> CreateForms[create_proc_form for each:<br/>- '21-686c' if submittable_686?<br/>- '21-674' if submittable_674?]
    
    CreateForms --> Success{Success?}
    
    Success -->|Yes| UpdateAttempt[Update BGS::SubmissionAttempt<br/>status: success]
    UpdateAttempt --> CallProcessor[ClaimProcessor.enqueue_submissions<br/>parent_claim_id, proc_id, claim_type_end_products]
    CallProcessor -.Async.-> SubmissionJobs[Submission Jobs<br/>Each receives claim_type_end_product<br/>0-1 BGS686cJob, 0-1 Claims686cJob<br/>0-n BGS674Job, 0-n Claims674Job<br/>per child claim]
    CallProcessor --> Complete[Job Complete]
    
    Success -->|No - All Errors| UpdateFailed[Update BGS::SubmissionAttempt<br/>status: failed<br/>error details]
    UpdateFailed --> CheckPerm{permanent_failure?<br/>BGSProcJob<br/>always returns false}
    CheckPerm -->|No - Transient| Retry{Retry Count<br/>< 16?}
    Retry -->|Yes| RetryJob[Sidekiq Retry<br/>exponential backoff]
    RetryJob -.Retry.-> Job
    
    Retry -->|No| Exhausted[Retries Exhausted<br/>sidekiq_retries_exhausted callback]
    Exhausted --> HandlePerm[handle_permanent_failure<br/>with pessimistic locking]
    HandlePerm --> MarkFailed[Mark SavedClaimGroups<br/>current & parent as FAILED]
    MarkFailed --> BackupJob[Trigger DependentBackupJob<br/>Lighthouse submission]
    
    CheckPerm -->|Yes - Permanent<br/>Not used for BGSProcJob| SkipRetry[Skip Sidekiq Retries]
    SkipRetry --> HandlePerm
    
    %% Styling
    classDef trigger fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    classDef process fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px
    classDef database fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef service fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef decision fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef failure fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    classDef epcode fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    
    class Start,CallProcessor,SubmissionJobs trigger
    class Job,CreateRecords,UpdateAttempt,UpdateFailed,HandlePerm,MarkFailed,Complete,RetryJob,Exhausted,SkipRetry process
    class DB1,DB2 database
    class CallBGS,CreateProc,CreateForms service
    class Success,Retry,CheckPerm decision
    class BackupJob failure
    class GetEPCodes,GetProcId epcode
```

## Key Points

- **EP Code Selection**: Queries active BGS claims and pending sibling submission attempts, then selects available codes from `[130, 131, 132, 134, 136, 137, 138, 139]` to prevent duplicate claim errors
- **BGS Service**: Creates vnp_proc and proc_form records in BGS, associating them with the selected EP codes
- **Database Tracking**: BGS::Submission and BGS::SubmissionAttempt track the operation
- **EP Code Propagation**: Selected EP codes passed to child submission jobs via `claim_type_end_product` option
- **Retry Logic**: Up to 16 retries with exponential backoff for all failures (BGSProcJob treats all errors as transient)
- **Success Path**: Triggers submission jobs with EP codes for actual form submission
- **Failure Path**: After 16 retries, triggers backup job with pessimistic locking to prevent race conditions
- **Error Handling**: On success handler failure, sends backup job immediately

## Next Steps

- **On Success**: [Submission Jobs](./submission_jobs_flow.md) - Parallel jobs submit to BGS and Lighthouse with assigned EP codes
- **On Failure**: [Backup Job](./backup_job_flow.md) - Lighthouse-only submission as fallback
