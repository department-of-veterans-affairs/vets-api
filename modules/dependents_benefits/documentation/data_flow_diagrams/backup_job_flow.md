# Backup Job Flow

[← Back to Overview](./full_data_flow.md)

Shows `DependentBackupJob` triggered after permanent failures. Submits to Lighthouse Benefits Intake API as fallback.

```mermaid
graph TD
    Start[DependentBackupJob#perform<br/>claim_id] --> LoadClaim[Load SavedClaim]
    
    LoadClaim --> DB1[(Lighthouse::Submission)]
    DB1 --> DB2[(Lighthouse::SubmissionAttempt)]
    
    DB2 --> InitService[Init BenefitsIntakeService]
    InitService --> GetUUID[Get UUID]
    GetUUID --> UpdateUUID[(Store benefits_intake_uuid)]
    
    UpdateUUID --> PrepareSubmission[Prepare Submission<br/>add_veteran_info<br/>get_files_from_claim]
    
    PrepareSubmission --> CollectClaims[Collect Child Claims<br/>686c and 674s]
    CollectClaims --> ProcessPDFs[Stamp PDFs<br/>VA.GOV + FDC Reviewed]
    ProcessPDFs --> SetMainForm[Set Main Form<br/>686c or first 674]
    SetMainForm --> CollectAttachments[Collect Attachments<br/>Other 674s + files]
    
    CollectAttachments --> GenerateMetadata[Generate Metadata<br/>veteran, file_number<br/>doc_type, business_line: CMP]
    
    GenerateMetadata --> Upload[Upload to Lighthouse<br/>main_document + attachments]
    
    Upload --> Success{Success?}
    
    Success -->|Yes| UpdateSuccess[(SubmissionAttempt: success)]
    UpdateSuccess --> MarkProcessing[(Parent Group: PROCESSING<br/>overwrites FAILED)]
    MarkProcessing --> SendNotification[Send In-Progress Email]
    SendNotification --> Cleanup[Cleanup PDFs]
    Cleanup --> Complete[Complete]
    
    Success -->|No| UpdateFailed[(SubmissionAttempt: failed)]
    UpdateFailed --> RetryCheck{Retries < 16?}
    RetryCheck -->|Yes| RetryJob[Sidekiq Retry]
    RetryJob -.Retry.-> Start
    
    RetryCheck -->|No| Exhausted[Exhausted]
    Exhausted --> SendFailure[Send Failure Email]
    SendFailure --> LogFailure[Log to Datadog]
    LogFailure --> CleanupFinal[Cleanup]
    CleanupFinal --> Failed[Failed]
    
    %% Styling
    classDef trigger fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    classDef process fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px
    classDef database fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef service fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef decision fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef failure fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    
    class Start trigger
    class LoadClaim,GetUUID,PrepareSubmission,CollectClaims,ProcessPDFs,SetMainForm,CollectAttachments,GenerateMetadata,SendNotification,SendFailure,LogFailure,Complete,Cleanup,CleanupFinal,RetryJob,Exhausted process
    class DB1,DB2,UpdateUUID,UpdateSuccess,UpdateFailed,MarkProcessing database
    class InitService,Upload service
    class Success,RetryCheck decision
    class Failed failure
```

## Key Points

- **Lighthouse Only**: Submits to Lighthouse Benefits Intake API only
- **PDF Processing**: Generates PDFs for all child claims, stamps with VA.GOV + FDC Reviewed
- **Main Form**: 686c if present, else first 674
- **Attachments**: Remaining 674s + persistent attachments
- **Metadata**: Veteran info, file_number, doc_type, business_line: CMP
- **Status Override**: Success marks parent as PROCESSING (overwrites FAILED)
- **Notifications**: In-progress email on success, failure email after 16 retries
- **Last Resort**: No further backup mechanism
