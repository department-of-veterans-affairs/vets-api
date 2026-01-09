# C4 Architecture Diagrams - GCIO Integration

## Level 1: System Context Diagram

This diagram shows how the GCIO Integration fits within the broader VA.gov ecosystem.

```mermaid
C4Context
    title System Context Diagram - GCIO Integration

    Person(veteran, "Veteran", "Submits benefits forms through VA.gov")
    
    System_Boundary(vagovapi, "VA.gov API (vets-api)") {
        System(vetsapi, "Vets API", "Rails application processing veteran forms")
    }
    
    System_Ext(lighthouse, "Lighthouse Benefits Intake", "VA's document intake system")
    System_Ext(gcio, "GCIO API", "Government Customer Information Office external API")
    System_Ext(datadog, "DataDog", "Application monitoring and observability")
    System_Ext(vanotify, "VA Notify", "Notification service for emails")
    
    Rel(veteran, vetsapi, "Submits form", "HTTPS/JSON")
    Rel(vetsapi, lighthouse, "Uploads PDF documents", "HTTPS/Multipart")
    Rel(vetsapi, lighthouse, "Polls submission status", "HTTPS/JSON")
    Rel(vetsapi, gcio, "Sends form data", "HTTPS/JSON")
    Rel(vetsapi, datadog, "Sends metrics and traces", "StatsD/APM")
    Rel(vetsapi, vanotify, "Sends error notifications", "HTTPS/JSON")
    
    UpdateRelStyle(veteran, vetsapi, $offsetY="-40", $offsetX="-50")
    UpdateRelStyle(vetsapi, lighthouse, $offsetY="-60")
    UpdateRelStyle(vetsapi, gcio, $offsetY="20")
```

## Level 2: Container Diagram

This diagram shows the major containers (applications/services) and how they interact for GCIO integration.

```mermaid
C4Container
    title Container Diagram - GCIO Integration

    Person(veteran, "Veteran", "Submits benefits forms")
    
    System_Boundary(vetsapi, "Vets API System") {
        Container(rails, "Rails Application", "Ruby on Rails", "Handles HTTP requests and form submissions")
        Container(sidekiq, "Sidekiq Workers", "Ruby/Sidekiq", "Background job processing")
        ContainerDb(postgres, "PostgreSQL Database", "PostgreSQL 14", "Stores form data, submission attempts, and GCIO status")
        ContainerDb(redis, "Redis", "Redis 6", "Job queue and cache")
    }
    
    System_Ext(lighthouse, "Lighthouse Benefits Intake API", "Document intake and status")
    System_Ext(gcio, "GCIO API", "External integration endpoint")
    System_Ext(datadog, "DataDog APM", "Monitoring and observability")
    
    Rel(veteran, rails, "Submits form", "HTTPS")
    Rel(rails, postgres, "Stores form submission", "SQL")
    Rel(rails, redis, "Enqueues jobs", "Redis Protocol")
    Rel(sidekiq, redis, "Dequeues jobs", "Redis Protocol")
    Rel(sidekiq, lighthouse, "Uploads PDF & polls status", "HTTPS")
    Rel(sidekiq, gcio, "Sends form JSON", "HTTPS")
    Rel(sidekiq, postgres, "Updates submission status", "SQL")
    Rel(rails, datadog, "Traces & metrics", "StatsD")
    Rel(sidekiq, datadog, "Traces & metrics", "StatsD")
    
    UpdateRelStyle(veteran, rails, $offsetY="-40")
    UpdateRelStyle(sidekiq, gcio, $offsetY="0")
```

## Level 3: Component Diagram

This diagram shows the internal components of the GCIO integration within the vets-api system.

```mermaid
C4Component
    title Component Diagram - GCIO Integration Components

    Container_Boundary(sidekiq, "Sidekiq Background Workers") {
        Component(polling_job, "BenefitsIntakeStatusJob", "Sidekiq Job", "Polls Lighthouse for submission status updates")
        Component(gcio_job, "Gcio::SubmitFormDataJob", "Sidekiq Job", "Sends form data to GCIO API with retry logic")
    }
    
    Container_Boundary(services, "Service Layer") {
        Component(gcio_service, "Gcio::Service", "Service Class", "HTTP client for GCIO API integration")
        Component(gcio_config, "Gcio::Configuration", "Configuration", "API endpoints and settings")
    }
    
    Container_Boundary(models, "Data Models") {
        Component(form_sub_attempt, "FormSubmissionAttempt", "ActiveRecord Model", "Tracks Lighthouse submission status")
        Component(gcio_submission, "GcioSubmission", "ActiveRecord Model", "Tracks GCIO API submission attempts")
        Component(form_submission, "FormSubmission", "ActiveRecord Model", "Stores original form data")
    }
    
    Container_Boundary(handlers, "Event Handlers") {
        Component(callback, "Gcio::SubmissionHandler", "Handler Class", "Triggered on successful vbms status")
    }
    
    ContainerDb_Ext(postgres, "PostgreSQL", "Database")
    System_Ext(lighthouse, "Lighthouse API", "External")
    System_Ext(gcio_api, "GCIO API", "External")
    Container_Ext(datadog, "DataDog", "Monitoring")
    
    Rel(polling_job, lighthouse, "GET /uploads/report", "HTTPS")
    Rel(polling_job, form_sub_attempt, "Updates status", "ActiveRecord")
    Rel(form_sub_attempt, callback, "Triggers on vbms! event", "AASM callback")
    Rel(callback, gcio_job, "Enqueues async job", "Sidekiq")
    Rel(gcio_job, form_submission, "Reads form data", "ActiveRecord")
    Rel(gcio_job, gcio_service, "Calls API", "Method call")
    Rel(gcio_service, gcio_config, "Loads config", "Method call")
    Rel(gcio_service, gcio_api, "POST /api/submissions", "HTTPS/JSON")
    Rel(gcio_job, gcio_submission, "Records attempt", "ActiveRecord")
    Rel(gcio_submission, postgres, "Persists data", "SQL")
    Rel(form_submission, postgres, "Reads data", "SQL")
    Rel(gcio_job, datadog, "Tracks metrics", "StatsD")
    Rel(gcio_service, datadog, "Traces requests", "APM")
```

## Sequence Diagram: Successful Flow

This sequence diagram shows the end-to-end flow when everything succeeds.

```mermaid
sequenceDiagram
    participant V as Veteran
    participant R as Rails Controller
    participant DB as PostgreSQL
    participant S1 as SubmitBenefitsIntakeClaim Job
    participant LH as Lighthouse API
    participant S2 as BenefitsIntakeStatusJob
    participant H as GcioSubmissionHandler
    participant S3 as SubmitFormDataJob
    participant GS as Gcio::Service
    participant GCIO as GCIO API
    participant DD as DataDog

    V->>R: Submit form (POST /api/v1/forms)
    R->>DB: Create FormSubmission
    R->>DB: Create FormSubmissionAttempt (pending)
    R->>S1: Enqueue job
    R-->>V: Return confirmation number
    
    S1->>LH: Request upload location
    LH-->>S1: Return presigned URL + UUID
    S1->>LH: Upload PDF + metadata
    LH-->>S1: 200 OK
    S1->>DB: Update attempt with UUID
    S1->>DD: Log success metrics
    
    Note over S2: Daily cron job (00:00 UTC)
    S2->>DB: Query pending attempts
    S2->>LH: POST /uploads/report (bulk status)
    LH-->>S2: Return status (vbms)
    S2->>DB: Update FormSubmissionAttempt.aasm_state = vbms
    
    Note over DB: AASM after_transition callback
    DB->>H: Trigger on vbms! event
    H->>DB: Check if GCIO enabled for form type
    H->>S3: Enqueue SubmitFormDataJob
    
    S3->>DB: Query FormSubmission for form data
    S3->>DB: Create GcioSubmission (pending)
    S3->>GS: Call submit(form_data)
    GS->>GCIO: POST /api/submissions (JSON payload)
    GCIO-->>GS: 200 OK + submission_id
    GS-->>S3: Return success response
    S3->>DB: Update GcioSubmission (success)
    S3->>DD: Log success metrics
    
    Note over S3: If failure, Sidekiq retries
    
```

## Sequence Diagram: Failure and Retry Flow

This sequence diagram shows what happens when GCIO API calls fail.

```mermaid
sequenceDiagram
    participant S as BenefitsIntakeStatusJob
    participant DB as PostgreSQL
    participant J as SubmitFormDataJob
    participant GS as Gcio::Service
    participant GCIO as GCIO API
    participant DD as DataDog
    participant VN as VA Notify

    S->>DB: Update status to vbms
    DB->>J: Enqueue job (attempt 1)
    
    J->>DB: Create GcioSubmission (pending)
    J->>GS: Call submit(form_data)
    GS->>GCIO: POST /api/submissions
    GCIO-->>GS: 500 Internal Server Error
    GS-->>J: Raise ServiceError
    J->>DB: Update GcioSubmission (attempt 1, error)
    J->>DD: Log failure metric
    
    Note over J: Sidekiq retry (exponential backoff)
    Note over J: Wait ~25 seconds
    
    J->>DB: Update GcioSubmission (attempt 2)
    J->>GS: Call submit(form_data)
    GS->>GCIO: POST /api/submissions
    GCIO-->>GS: 503 Service Unavailable
    GS-->>J: Raise ServiceError
    J->>DB: Update GcioSubmission (attempt 2, error)
    J->>DD: Log failure metric
    
    Note over J: Continue retrying...
    Note over J: After 16 retries (~2 days)
    
    J->>DB: Update GcioSubmission (failed)
    J->>DD: Log exhaustion metric
    J->>VN: Send failure notification (if configured)
```

## Data Flow Diagram

This diagram shows how data flows through the system.

```mermaid
flowchart TD
    A[Veteran Submits Form] --> B[FormSubmission Created]
    B --> C[Form Data Encrypted in DB]
    B --> D[FormSubmissionAttempt Created]
    D --> E[Lighthouse Upload Job]
    E --> F[PDF Generated from Form Data]
    F --> G[Upload to Lighthouse]
    G --> H[Status: pending]
    
    H --> I[Daily Polling Job]
    I --> J{Status Check}
    J -->|pending| I
    J -->|vbms| K[Update to VBMS Status]
    J -->|error| L[Mark as Failed]
    
    K --> M{GCIO Enabled?}
    M -->|Yes| N[Trigger GCIO Handler]
    M -->|No| O[End]
    
    N --> P[Enqueue SubmitFormDataJob]
    P --> Q[Create GcioSubmission Record]
    Q --> R[Read Form Data from FormSubmission]
    R --> S[Call Gcio::Service]
    S --> T{API Response}
    
    T -->|Success| U[Update GcioSubmission: success]
    T -->|Failure| V[Update GcioSubmission: retry attempt]
    
    V --> W{Retry Count}
    W -->|< 16| X[Sidekiq Retry with Backoff]
    W -->|>= 16| Y[Mark as Failed]
    
    X --> P
    U --> Z[Log Success Metrics]
    Y --> AA[Log Failure + Notify]
```

## Component Dependencies

```mermaid
graph LR
    A[FormSubmissionAttempt] -->|has_one| B[FormSubmission]
    B -->|has_many| A
    B -->|belongs_to| C[SavedClaim]
    B -->|has_many| D[GcioSubmission]
    D -->|belongs_to| B
    
    E[BenefitsIntakeStatusJob] -.->|updates| A
    F[Gcio::SubmissionHandler] -.->|observes| A
    F -.->|enqueues| G[Gcio::SubmitFormDataJob]
    G -.->|creates/updates| D
    G -.->|reads| B
    G -.->|calls| H[Gcio::Service]
    H -.->|uses| I[Gcio::Configuration]
    
    style A fill:#e1f5ff
    style B fill:#e1f5ff
    style D fill:#e1f5ff
    style G fill:#fff4e1
    style H fill:#f0e1ff
```

---

## Diagram Legends

### C4 Notation
- **Person**: External user interacting with the system
- **System**: Software system
- **Container**: Application, database, or service
- **Component**: Module or class within a container
- **Rel**: Relationship/interaction between elements

### Color Coding
- Blue (#e1f5ff): Data models
- Yellow (#fff4e1): Background jobs
- Purple (#f0e1ff): Service classes
- Gray (default): External systems


