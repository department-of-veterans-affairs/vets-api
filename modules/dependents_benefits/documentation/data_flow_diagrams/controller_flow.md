# Controller Data Flow

[← Back to Overview](./full_data_flow.md)

This diagram shows the flow through `DependentsBenefits::V0::ClaimsController` from form submission through job enqueue.

```mermaid
graph TD
    Start[User Submits Form] --> CreateClaim[Create SavedClaim<br/>form: dependent_params.to_json]
    
    CreateClaim --> CheckIPF{InProgressForm<br/>exists?}
    CheckIPF -->|Yes| AssignDate[Assign form_start_date]
    CheckIPF -->|No| ValidateClaim
    AssignDate --> ValidateClaim{Validate & Save}
    
    ValidateClaim -->|Invalid| Error[Return 422]
    ValidateClaim -->|Valid| DB1[(SavedClaim saved)]
    
    DB1 --> CollectUser[Collect UserData]
    
    CollectUser --> CreateGroup[Create SavedClaimGroup<br/>parent + child link<br/>user_data encrypted]
    
    CreateGroup --> DB2[(Parent SavedClaimGroup)]
    
    DB2 --> ValidateType{submittable_686?<br/>OR submittable_674?}
    
    ValidateType -->|No| ErrorType[Return 422]
    ValidateType -->|Yes| CheckType{Check Types}
    
    CheckType -->|686c| Gen686[Claim686cGenerator<br/>Creates child 686c claim]
    CheckType -->|674| Gen674[Claim674Generator<br/>One per student]
    
    Gen686 --> DB3[(SavedClaim: 686c)]
    DB3 --> DB4[(SavedClaimGroup: 686c)]
    
    Gen674 --> DB5[(SavedClaim: 674)]
    DB5 --> DB6[(SavedClaimGroup: 674)]
    
    DB4 --> Enqueue[ClaimProcessor.create_proc_forms<br/>Enqueues BGSProcJob]
    DB6 --> Enqueue
    
    Enqueue --> Return200[Return 200<br/>SavedClaimSerializer]
    
    Enqueue -.Async.-> AsyncJob[BGSProcJob.perform_async<br/>parent_claim_id]
    
    %% Styling
    classDef process fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px
    classDef database fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    classDef decision fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef error fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    classDef trigger fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px
    
    class Start,CreateClaim,CollectUser,CreateGroup,Gen686,Gen674,Enqueue,Return200 process
    class DB1,DB2,DB3,DB4,DB5,DB6 database
    class CheckIPF,ValidateClaim,ValidateType,CheckType decision
    class Error,ErrorType error
    class AsyncJob trigger
```

## Next Steps

After the controller returns 200, background processing begins:

- **[BGS Proc Job](./bgs_proc_job_flow.md)** - Creates vnp_proc in BGS and selects EP codes
- **[Submission Jobs](./submission_jobs_flow.md)** - Parallel submission jobs with EP codes
- **[Backup Job](./backup_job_flow.md)** - Lighthouse backup on failures
