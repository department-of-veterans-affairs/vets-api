# C4 Architecture Diagrams - GCIO Form Intake Integration

## Level 1: System Context Diagram

This diagram shows how the GCIO Form Intake Integration fits within the broader VA.gov ecosystem.

```mermaid
C4Context
    title System Context Diagram - GCIO Form Intake Integration

    Person(veteran, "Veteran", "Submits benefits forms through VA.gov")
    
    System_Boundary(vagovapi, "VA.gov API (vets-api)") {
        System(vetsapi, "Vets API", "Rails application processing veteran forms")
    }
    
    System_Ext(lighthouse, "Lighthouse Benefits Intake", "VA's document intake system")
    System_Ext(fwdproxy, "fwdproxy", "Outbound gateway with mTLS")
    System_Ext(gcio, "GCIO Digitization API", "Form intake API endpoint")
    System_Ext(ssm, "AWS SSM", "Certificate storage")
    System_Ext(datadog, "DataDog", "Application monitoring and observability")
    System_Ext(vanotify, "VA Notify", "Notification service for emails")
    
    Rel(veteran, vetsapi, "Submits form", "HTTPS/JSON")
    Rel(vetsapi, lighthouse, "Uploads PDF documents", "HTTPS/Multipart")
    Rel(vetsapi, lighthouse, "Polls submission status", "HTTPS/JSON")
    Rel(vetsapi, fwdproxy, "Sends form data", "HTTPS")
    Rel(fwdproxy, ssm, "Retrieves certificates", "AWS API")
    Rel(fwdproxy, gcio, "Forwards with mTLS", "HTTPS/mTLS")
    Rel(vetsapi, datadog, "Sends metrics and traces", "StatsD/APM")
    Rel(vetsapi, vanotify, "Sends error notifications", "HTTPS/JSON")
    
    UpdateRelStyle(veteran, vetsapi, $offsetY="-40", $offsetX="-50")
    UpdateRelStyle(vetsapi, lighthouse, $offsetY="-60")
    UpdateRelStyle(fwdproxy, gcio, $offsetY="20")
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
    System_Ext(fwdproxy, "fwdproxy", "Outbound proxy")
    System_Ext(gcio, "GCIO Digitization API", "Form intake endpoint")
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
        Component(gcio_job, "FormIntake::SubmitFormDataJob", "Sidekiq Job", "Sends form data to GCIO digitization API via fwdproxy with retry logic")
    }
    
    Container_Boundary(services, "Service Layer") {
        Component(gcio_service, "FormIntake::Service", "Service Class", "HTTP client for GCIO digitization API integration via fwdproxy")
        Component(gcio_config, "FormIntake::Configuration", "Configuration", "API endpoints and settings")
    }
    
    Container_Boundary(models, "Data Models") {
        Component(form_sub_attempt, "FormSubmissionAttempt", "ActiveRecord Model", "Tracks Lighthouse submission status")
        Component(form_intake_submission, "FormIntakeSubmission", "ActiveRecord Model", "Tracks GCIO digitization API submission attempts")
        Component(form_submission, "FormSubmission", "ActiveRecord Model", "Stores original form data")
    }
    
    Container_Boundary(handlers, "Event Handlers") {
        Component(callback, "FormIntake::SubmissionHandler", "Handler Class", "Triggered on successful vbms status")
    }
    
    ContainerDb_Ext(postgres, "PostgreSQL", "Database")
    System_Ext(lighthouse, "Lighthouse API", "External")
    Container_Ext(fwdproxy, "fwdproxy", "Outbound Proxy")
    System_Ext(gcio_api, "GCIO Digitization API", "dev-api.digitization.gcio.com")
    Container_Ext(datadog, "DataDog", "Monitoring")
    
    Rel(polling_job, lighthouse, "GET /uploads/report", "HTTPS")
    Rel(polling_job, form_sub_attempt, "Updates status", "ActiveRecord")
    Rel(form_sub_attempt, callback, "Triggers on vbms! event", "AASM callback")
    Rel(callback, gcio_job, "Enqueues async job", "Sidekiq")
    Rel(gcio_job, form_submission, "Reads form data", "ActiveRecord")
    Rel(gcio_job, gcio_service, "Calls API", "Method call")
    Rel(gcio_service, gcio_config, "Loads config", "Method call")
    Rel(gcio_service, gcio_api, "POST /api/submissions", "HTTPS/JSON")
    Rel(gcio_job, form_intake_submission, "Records attempt", "ActiveRecord")
    Rel(form_intake_submission, postgres, "Persists data", "SQL")
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
    participant S3 as SubmitFormDataJob
    participant GS as FormIntake::Service
    participant FP as fwdproxy
    participant GCIO as GCIO Digitization API
    participant IBM as IBM Mail Automation
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
    
    Note over S1: IMMEDIATE: Trigger GCIO after Lighthouse success
    S1->>S3: Enqueue SubmitFormDataJob (async)
    S1->>DD: Log GCIO trigger metric
    Note over S1: Lighthouse job continues (non-blocking)
    
    Note over S2,LH: Later: Daily polling (monitoring only)
    S2->>DB: Query pending attempts
    S2->>LH: POST /uploads/report (bulk status)
    LH-->>S2: Return status (vbms)
    S2->>DB: Update FormSubmissionAttempt.aasm_state = vbms
    
    S3->>DB: Query FormSubmission for form data
    S3->>DB: Create FormIntakeSubmission (pending)
    S3->>GS: Call submit(form_data)
    GS->>FP: Route through fwdproxy
    FP->>GCIO: POST /api/submissions (JSON payload, mTLS)
    GCIO-->>FP: 200 OK + submission_id
    FP-->>GS: Return response
    GS-->>S3: Return success response
    S3->>DB: Update FormIntakeSubmission (success)
    S3->>DD: Log success metrics (includes benefits_intake_uuid)
    
    Note over S3,GCIO: Structured data now available within seconds
    
    Note over IBM: IBM Mail Automation (later)
    IBM->>GCIO: Query for UUID (from Lighthouse)
    GCIO-->>IBM: Return structured form data
    IBM->>VBMS: Process PDF with structured data
    
    Note over S3: All logs/metrics include benefits_intake_uuid<br/>for correlation with Lighthouse submission
    Note over S3: If failure, Sidekiq retries
    
```

## Sequence Diagram: Failure and Retry Flow

This sequence diagram shows what happens when GCIO digitization API calls fail.

```mermaid
sequenceDiagram
    participant S as BenefitsIntakeStatusJob
    participant DB as PostgreSQL
    participant J as SubmitFormDataJob
    participant GS as FormIntake::Service
    participant FP as fwdproxy
    participant GCIO as GCIO Digitization API
    participant DD as DataDog
    participant VN as VA Notify

    S->>DB: Update status to vbms
    DB->>J: Enqueue job (attempt 1)
    
    J->>DB: Create FormIntakeSubmission (pending)
    J->>GS: Call submit(form_data)
    GS->>GCIO: POST /api/submissions
    GCIO-->>GS: 500 Internal Server Error
    GS-->>J: Raise ServiceError
    J->>DB: Update FormIntakeSubmission (attempt 1, error)
    J->>DD: Log failure metric (includes benefits_intake_uuid)
    
    Note over J: Sidekiq retry (exponential backoff)
    Note over J: Wait ~25 seconds
    
    J->>DB: Update FormIntakeSubmission (attempt 2)
    J->>GS: Call submit(form_data)
    GS->>GCIO: POST /api/submissions
    GCIO-->>GS: 503 Service Unavailable
    GS-->>J: Raise ServiceError
    J->>DB: Update FormIntakeSubmission (attempt 2, error)
    J->>DD: Log failure metric (includes benefits_intake_uuid)
    
    Note over J: Continue retrying...
    Note over J: After 16 retries (~2 days)
    
    J->>DB: Update FormIntakeSubmission (failed)
    J->>DD: Log exhaustion metric (includes benefits_intake_uuid)
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
    G --> H{Upload Success?}
    
    H -->|No| I[Retry Upload]
    H -->|Yes| J[Lighthouse Returns UUID]
    
    J --> K{GCIO Enabled?}
    K -->|Yes| L[IMMEDIATE: Enqueue SubmitFormDataJob]
    K -->|No| M[Continue Without GCIO]
    
    L --> N[Create FormIntakeSubmission Record]
    N --> O[FormIntake Job Processes Async]
    O --> P[Read Form Data from FormSubmission]
    P --> Q[Call FormIntake::Service]
    Q --> R[Route via fwdproxy with mTLS]
    R --> S{API Response}
    
    S -->|Success| T[Update FormIntakeSubmission: success]
    S -->|Failure| U[Update FormIntakeSubmission: retry attempt]
    
    U --> V{Retry Count}
    V -->|< 16| W[Sidekiq Retry with Backoff]
    V -->|>= 16| X[Mark as Failed]
    
    W --> O
    T --> Y[Structured Data Ready at GCIO]
    Y --> Z[IBM Queries GCIO Using UUID]
    Z --> AA[IBM Processes to VBMS]
    X --> AB[Log Failure + Notify]
    
    M --> AC[Normal Lighthouse Flow Continues]
```

## Component Dependencies

```mermaid
graph LR
    A[FormSubmissionAttempt] -->|has_one| B[FormSubmission]
    B -->|has_many| A
    B -->|belongs_to| C[SavedClaim]
    B -->|has_many| D[FormIntakeSubmission]
    D -->|belongs_to| B
    
    E[BenefitsIntakeStatusJob] -.->|updates| A
    F[FormIntake::SubmissionHandler] -.->|observes| A
    F -.->|enqueues| G[FormIntake::SubmitFormDataJob]
    G -.->|creates/updates| D
    G -.->|reads| B
    G -.->|calls| H[FormIntake::Service]
    H -.->|uses| I[FormIntake::Configuration]
    
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


