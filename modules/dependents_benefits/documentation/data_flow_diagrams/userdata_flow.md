# UserData Collection Flow

[← Back to Overview](./full_data_flow.md) | [← Back to Controller Flow](./controller_flow.md)

Shows `DependentsBenefits::UserData.new(current_user, claim.parsed_form)` during controller flow.

```mermaid
graph TD
    Start[UserData.new<br/>user, claim_data] --> GetName[Get Name<br/>user → claim_data fallback]
    
    GetName --> GetIds[Get IDs<br/>ssn, uuid, icn, participant_id<br/>from user only]
    
    GetIds --> GetContact[Get Contact<br/>birth_date, email<br/>user → claim_data fallback]
    
    GetContact --> GetVAEmail[Get VA Email<br/>va_profile_email → email]
    
    GetVAEmail --> GetFileNum[Get VA File Number<br/>BGS by participant_id<br/>→ by ssn → ssn]
    
    GetFileNum --> GetJSON[Build JSON]
    
    GetJSON --> Return[Return JSON<br/>Store in SavedClaimGroup.user_data]
    
    Start -->|Error| ErrorHandler[UnprocessableEntity]
    GetJSON -->|Error| ErrorHandler
    
    %% Styling
    classDef process fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px
    classDef error fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    
    class Start,GetName,GetIds,GetContact,GetVAEmail,GetFileNum,GetJSON,Return process
    class ErrorHandler error
```

## Key Points

- **Fallback Strategy**: User object preferred, claim_data fallback for name/contact
- **BGS Lookup**: VA File Number via participant_id → ssn → direct ssn fallback
- **Error Handling**: Raises UnprocessableEntity on failure
- **Storage**: JSON stored encrypted in `SavedClaimGroup.user_data` for background jobs
