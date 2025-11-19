# UserData Collection Flow

[← Back to Overview](./full_data_flow.md) | [← Back to Controller Flow](./controller_flow.md)

This diagram shows what happens inside `DependentsBenefits::UserData.new(current_user, claim.parsed_form)` during the controller flow.

```mermaid
graph TD
    Start[UserData.new called<br/>user, claim_data] --> GetName[Get Name Fields<br/>first, middle, last, common<br/>From user, fallback to claim_data]
    
    GetName --> GetIds[Get Identifiers<br/>ssn, uuid, icn, participant_id<br/>From user object only]
    
    GetIds --> GetContact[Get Contact Info<br/>birth_date, email<br/>From user, fallback to claim_data]
    
    GetContact --> GetVAEmail[Get VA Profile Email<br/>user.va_profile_email<br/>Fallback to email field]
    
    GetVAEmail --> GetFileNum[Get VA File Number<br/>BGS find_person_by_ptcpnt_id<br/>Fallback to find_by_ssn<br/>Fallback to ssn]
    
    GetFileNum --> Complete[All Attributes Collected]
    
    Complete --> GetJSON[get_user_json<br/>Build JSON structure]
    
    GetJSON --> Return[Return JSON String<br/>Stored in SavedClaimGroup.user_data]
    
    %% Error Handling
    Start -->|Exception| ErrorHandler[Raise UnprocessableEntity<br/>Could not initialize user data]
    
    GetJSON -->|Exception| ErrorHandler2[Raise UnprocessableEntity<br/>Could not generate user hash]
    
    %% Styling
    classDef process fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px
    classDef service fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef decision fill:#fff9c4,stroke:#f57f17,stroke-width:2px
    classDef error fill:#ffcdd2,stroke:#b71c1c,stroke-width:2px
    
    class Start,GetName,GetIds,GetContact,GetVAEmail,GetFileNum,GetJSON,Complete,Return process
    class ErrorHandler,ErrorHandler2 error
```

## Key Points

- **Fallback Strategy**: User object data is preferred, with claim_data as fallback for some fields
- **BGS Integration**: VA File Number requires BGS lookup with multiple fallback strategies
- **Error Handling**: Raises UnprocessableEntity if user data cannot be collected
- **Storage**: Final JSON stored in `SavedClaimGroup.user_data` for use by background jobs
