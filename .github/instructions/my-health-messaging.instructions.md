---
applyTo: "modules/my_health/app/controllers/my_health/sm_controller.rb,modules/my_health/app/controllers/my_health/v1/messages_controller.rb,modules/my_health/app/controllers/my_health/v1/message_drafts_controller.rb,modules/my_health/app/controllers/my_health/v1/folders_controller.rb,modules/my_health/app/controllers/my_health/v1/threads_controller.rb,modules/my_health/app/controllers/my_health/v1/triage_teams_controller.rb,modules/my_health/app/controllers/my_health/v1/all_triage_teams_controller.rb,modules/my_health/app/controllers/my_health/v1/attachments_controller.rb,modules/my_health/app/controllers/my_health/v1/messaging_preferences_controller.rb,modules/my_health/app/serializers/my_health/v1/message_serializer.rb,modules/my_health/app/serializers/my_health/v1/messages_serializer.rb,modules/my_health/app/serializers/my_health/v1/message_details_serializer.rb,modules/my_health/app/serializers/my_health/v1/message_draft_serializer.rb,modules/my_health/app/serializers/my_health/v1/folder_serializer.rb,modules/my_health/app/serializers/my_health/v1/triage_team_serializer.rb,modules/my_health/app/serializers/my_health/v1/all_triage_teams_serializer.rb,modules/my_health/app/serializers/my_health/v1/attachment_serializer.rb,modules/my_health/app/serializers/my_health/v1/category_serializer.rb,modules/my_health/app/serializers/my_health/v1/messaging_preference_serializer.rb,modules/my_health/app/serializers/my_health/v1/message_signature_serializer.rb,modules/my_health/app/serializers/my_health/v1/threads_serializer.rb,modules/my_health/config/routes.rb,modules/my_health/spec/requests/my_health/v1/messaging/**/*,lib/sm/**/*,app/models/message.rb,app/models/message_draft.rb,app/models/folder.rb,app/models/attachment.rb,app/models/triage_team.rb,app/models/message_search.rb,app/models/messaging_preference.rb,app/models/messaging_signature.rb,app/policies/mhv_messaging_policy.rb,spec/models/message*,spec/lib/sm/**/*"
---

# Copilot Instructions for My Health / Secure Messaging

**Path-Specific Instructions for Secure Messaging**

These instructions automatically apply when working with:
- **Controllers:** All controllers inheriting from `MyHealth::SMController`
  - `MessagesController`, `MessageDraftsController`, `FoldersController`
  - `ThreadsController`, `AttachmentsController`
  - `TriageTeamsController`, `AllTriageTeamsController`
  - `MessagingPreferencesController`
- **Client Library:** `lib/sm/` - SM::Client for MHV API integration
- **Models:** `Message`, `MessageDraft`, `Folder`, `Attachment`, `TriageTeam`, `MessagingPreference`, `MessagingSignature`, `MessageSearch`
- **Serializers:** All SM-related JSONAPI serializers in `modules/my_health/app/serializers/my_health/v1/`
- **Policy:** `app/policies/mhv_messaging_policy.rb` - Authorization policy for Secure Messaging access

---

## 📚 Secure Messaging Module Structure

### SMController Hierarchy (`modules/my_health/`)
All Secure Messaging controllers inherit from `SMController` which provides:
- MHV session management via `SM::Client`
- Authentication checks (`authorize_mhv_user`)
- JSON API pagination support
- Caching support via `use_cache?` parameter

**Base Controller:**
- `modules/my_health/app/controllers/my_health/sm_controller.rb` - Base controller for all Secure Messaging features

**Message Controllers (inherit from SMController):**
- `modules/my_health/app/controllers/my_health/v1/messages_controller.rb` - Message CRUD operations (create, show, destroy, thread, reply, categories, signature, move)
- `modules/my_health/app/controllers/my_health/v1/message_drafts_controller.rb` - Draft management (create, update, create_reply_draft, update_reply_draft)
- `modules/my_health/app/controllers/my_health/v1/threads_controller.rb` - Message thread operations (index, move)

**Folder Controllers (inherit from SMController):**
- `modules/my_health/app/controllers/my_health/v1/folders_controller.rb` - Folder management (index, show, create, update, destroy, search)

**Recipient/Triage Team Controllers (inherit from SMController):**
- `modules/my_health/app/controllers/my_health/v1/triage_teams_controller.rb` - Triage team queries (index) - patient's assigned teams
- `modules/my_health/app/controllers/my_health/v1/all_triage_teams_controller.rb` - All triage teams query (index) - all available teams

**Attachment Controllers (inherit from SMController):**
- `modules/my_health/app/controllers/my_health/v1/attachments_controller.rb` - Attachment download (show)

**Preferences Controllers (inherit from SMController):**
- `modules/my_health/app/controllers/my_health/v1/messaging_preferences_controller.rb` - Email notification preferences and signature management (show, update, update_triage_team_preferences, signature, update_signature)

**Serializers (JSONAPI format):**
- `modules/my_health/app/serializers/my_health/v1/message_serializer.rb` - Single message
- `modules/my_health/app/serializers/my_health/v1/messages_serializer.rb` - Message collection
- `modules/my_health/app/serializers/my_health/v1/message_details_serializer.rb` - Message with full thread details
- `modules/my_health/app/serializers/my_health/v1/message_draft_serializer.rb` - Message drafts
- `modules/my_health/app/serializers/my_health/v1/folder_serializer.rb` - Folders
- `modules/my_health/app/serializers/my_health/v1/triage_team_serializer.rb` - Triage teams (recipients)
- `modules/my_health/app/serializers/my_health/v1/all_triage_teams_serializer.rb` - All triage teams
- `modules/my_health/app/serializers/my_health/v1/attachment_serializer.rb` - Attachments
- `modules/my_health/app/serializers/my_health/v1/category_serializer.rb` - Message categories
- `modules/my_health/app/serializers/my_health/v1/messaging_preference_serializer.rb` - Preferences
- `modules/my_health/app/serializers/my_health/v1/message_signature_serializer.rb` - User signature
- `modules/my_health/app/serializers/my_health/v1/threads_serializer.rb` - Message threads

### Routes (`modules/my_health/config/routes.rb`)
**Messaging namespace (`/my_health/v1/messaging/`):**

```ruby
scope :messaging do
  # Recipients (Triage Teams)
  resources :triage_teams, path: 'recipients'        # GET /recipients
  resources :all_triage_teams, path: 'allrecipients' # GET /allrecipients

  # Folders
  resources :folders do
    resources :threads                                # GET /folders/:folder_id/threads
    post :search, on: :member                         # POST /folders/:id/search
  end

  # Threads
  resources :threads do
    patch :move, on: :member                          # PATCH /threads/:id/move
  end

  # Messages
  resources :messages do
    get :thread, on: :member                          # GET /messages/:id/thread
    get :categories, on: :collection                  # GET /messages/categories
    get :signature, on: :collection                   # GET /messages/signature
    patch :move, on: :member                          # PATCH /messages/:id/move
    post :reply, on: :member                          # POST /messages/:id/reply
    resources :attachments, only: [:show]             # GET /messages/:message_id/attachments/:id
  end

  # Message Drafts
  resources :message_drafts do
    post ':reply_id/replydraft', action: :create_reply_draft  # POST /message_drafts/:reply_id/replydraft
    put ':reply_id/replydraft/:draft_id', action: :update_reply_draft  # PUT /message_drafts/:reply_id/replydraft/:draft_id
  end

  # Preferences
  resource :preferences, controller: 'messaging_preferences' do
    post 'recipients', action: :update_triage_team_preferences  # POST /preferences/recipients
    get :signature, on: :member                      # GET /preferences/signature
    post :signature, on: :member, action: :update_signature  # POST /preferences/signature
  end
end
```

### SM Client Library (`lib/sm/`)
Client for interacting with MHV (My HealtheVet) Secure Messaging API:

**Core Files:**
- `lib/sm/client.rb` - Main SM client with all API operations
- `lib/sm/configuration.rb` - Faraday configuration for SM endpoints
- `lib/sm/client_session.rb` - Session management for MHV authentication
- `lib/sm/middleware/response/sm_parser.rb` - Response parsing middleware (see detailed explanation below)

**Key Client Methods:**
```ruby
# Messages
client.get_messages(folder_id, page, per_page)
client.get_message(message_id)
client.post_create_message(params, poll_for_status: false)
client.post_create_message_with_attachment(params, poll_for_status: false)
client.post_create_message_with_lg_attachments(params, poll_for_status: false)
client.post_create_message_reply(message_id, params, poll_for_status: false)
client.post_create_message_reply_with_attachment(message_id, params, poll_for_status: false)
client.post_create_message_reply_with_lg_attachment(message_id, params, poll_for_status: false)
client.delete_message(message_id)

# Folders
client.get_folders
client.get_folder(folder_id)
client.post_create_folder(name)
client.delete_folder(folder_id)

# Triage Teams
client.get_triage_teams

# Drafts
client.get_message_draft(draft_id)
client.post_create_message_draft(params)
client.put_message_draft(draft_id, params)

# Attachments
client.get_attachment(message_id, attachment_id)

# Categories
client.get_categories

# Preferences
client.get_preferences
client.set_preferences(params)
```

### SM Response Parser Middleware (`lib/sm/middleware/response/sm_parser.rb`)

**Purpose:**
Faraday middleware that normalizes and transforms MHV Secure Messaging API responses into a consistent format for the application. Handles the diverse response structures from MHV API and converts them into a standardized envelope.

**Response Envelope Structure:**
All parsed responses follow this structure:
```ruby
{
  data: <normalized_response_data>,
  errors: <extracted_errors>,
  metadata: <extracted_metadata>
}
```

**Key Responsibilities:**

1. **Content-Type Detection**
   - Only processes JSON responses (`content-type: application/json`)
   - Passes through non-JSON responses unchanged

2. **Response Type Detection & Normalization**
   The parser identifies and normalizes different MHV API response types:

   - **Messages** - Detects by `:recipient_id` key, normalizes attachments structure
   - **Threads** - Detects by `:thread_id` key in array items
   - **Folders** - Detects by `:system_folder` key or nested `:folder` key
   - **Triage Teams** - Detects by `:triage_team_id` key
   - **All Triage Teams** - Detects by `:associated_triage_groups` key, extracts metadata
   - **Categories** - Detects by `:message_category_type` key
   - **Preferences** - Detects by `:notify_me` or numeric keys
   - **Signature** - Detects by `:signature_name` key
   - **Presigned S3 URLs** - Detects URL strings for attachment downloads
   - **AWS S3 Metadata** - Detects objects with `:url`, `:mime_type`, `:name` keys
   - **Status** - Detects by `:status` key for operation status responses

3. **Attachment Normalization (`fix_attachments`)**
   Critical transformation for message attachments:
   ```ruby
   # MHV API format (nested):
   {
     id: 123,
     attachments: [
       { attachment: [{ id: 1, name: 'file.pdf' }, { id: 2, name: 'doc.txt' }] }
     ]
   }

   # Normalized format (flat with message_id):
   {
     id: 123,
     attachments: [
       { id: 1, name: 'file.pdf', message_id: 123 },
       { id: 2, name: 'doc.txt', message_id: 123 }
     ]
   }
   ```
   - Removes nested `:attachment` wrapper
   - Flattens array structure
   - Injects `message_id` into each attachment for reference
   - Handles both single messages and message arrays

4. **Metadata Extraction (`split_meta_fields!`)**
   - Extracts metadata from All Triage Teams responses
   - Separates metadata from data payload
   - Places metadata in response envelope's `:metadata` key

5. **Error Extraction (`split_errors!`)**
   - Extracts `:errors` key from response body
   - Places errors in response envelope's `:errors` key
   - Returns empty hash if no errors present

**Usage in SM::Configuration:**
```ruby
# Registered as Faraday middleware
Faraday::Response.register_middleware sm_parser: SM::Middleware::Response::SMParser

# Applied in Faraday connection stack
conn.response :sm_parser
```

**Key Methods:**

- `on_complete(env)` - Faraday hook, processes response after completion
- `parse(body)` - Main parsing logic, returns normalized envelope
- `normalize_message(object)` - Handles message/array normalization
- `fix_attachments(message_json)` - Critical attachment structure transformation
- `parsed_<type>` methods - Type-specific detection methods (e.g., `parsed_folders`, `parsed_triage`)

**Important Considerations:**

1. **Type Detection Order Matters** - Parser checks types in specific order via OR chain
2. **Attachment Structure** - Always uses normalized flat structure with `message_id`
3. **Metadata Separation** - Metadata extracted before data processing
4. **Error Handling** - Errors removed from data payload, placed in envelope
5. **Passthrough for Non-JSON** - Only processes JSON responses, passes others unchanged

**When Working with Responses:**
- Expect all SM::Client responses to have `data`, `errors`, `metadata` structure
- Attachment arrays will be flat with `message_id` injected
- Check `errors` key for API-level errors
- Check `metadata` key for pagination/additional info (especially with All Triage Teams)

**Common Issues:**
- If attachment structure seems wrong, check `fix_attachments` logic
- If response type not detected, verify detection key in `parsed_<type>` method
- If metadata missing, check `split_meta_fields!` extraction logic

---

## 🎯 Secure Messaging Models

### Message Model (`app/models/message.rb`)

**Validations:**
```ruby
# Required for new messages (NOT for replies)
validates :category, :recipient_id, presence: true, unless: proc { reply? }

# Always required
validates :body, presence: true

# File upload validations (if uploads present)
validate :total_file_count_validation
validate :each_upload_size_validation
validate :total_upload_size_validation
```

**File Upload Limits:**

**Standard Attachments:**
- Max 4 files
- Max 6 MB per file
- Max 10 MB total

**Large Attachments** (when `is_large_attachment_upload: true`):
- Max 10 files
- Max 25 MB per file
- Max 25 MB total

**Key Methods:**
```ruby
message = Message.new(params)
message.as_reply        # Marks message as reply (skips category/recipient validation)
message.reply?          # Returns true if marked as reply
message.valid?          # Runs all validations
```

**Attributes:**
```ruby
:id, :category, :subject, :body, :attachment, :sent_date,
:sender_id, :sender_name, :recipient_id, :recipient_name,
:read_receipt, :triage_group_name, :proxy_sender_name,
:attachments, :has_attachments, :is_large_attachment_upload,
:uploads  # For validation only, not rendered
```

### Other Secure Messaging Models

**MessageDraft** (`app/models/message_draft.rb`)
- Inherits from `Message`
- Additional validation for reply drafts vs regular drafts
- Used by `MessageDraftsController`

**Folder** (`app/models/folder.rb`)
- Represents message folders (Inbox, Sent, Drafts, Custom folders)
- Used by `FoldersController`
- Attributes: `:id`, `:name`, `:count`, `:unread_count`, `:system_folder`

**Attachment** (`app/models/attachment.rb`)
- Message attachments metadata
- Used by `AttachmentsController`
- Attributes: `:id`, `:name`, `:size`, `:attachment_type`

**TriageTeam** (`app/models/triage_team.rb`)
- Healthcare provider teams that can receive messages
- Used by `TriageTeamsController` and `AllTriageTeamsController`
- Attributes: `:triage_team_id`, `:name`, `:relation_type`, `:preferred_team`

**MessagingPreference** (`app/models/messaging_preference.rb`)
- Email notification preferences for secure messages
- Used by `MessagingPreferencesController`
- Attributes: `:email_address`, `:frequency` (none/each_message/daily)

**MessagingSignature** (`app/models/messaging_signature.rb`)
- User signature for messages
- Used by `MessagingPreferencesController`
- Attributes: `:signature_name`, `:signature_title`, `:include_signature`

**MessageSearch** (`app/models/message_search.rb`)
- Search parameters for folder message search
- Used by `FoldersController#search`
- Attributes: search criteria for filtering messages

---

## 🔧 Common Patterns

### Controller Pattern for Messages

```ruby
module MyHealth
  module V1
    class MessagesController < SMController
      # Always extend timeout for OH triage groups
      before_action :extend_timeout, only: %i[create reply], if: :oh_triage_group?

      def create
        # 1. Create message with large attachment flag
        message = Message.new(message_params.merge(upload_params)
                  .merge(is_large_attachment_upload: use_large_attachment_upload))

        # 2. Validate before sending
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        # 3. Prepare params
        message_params_h = prepare_message_params_h
        create_message_params = { message: message_params_h }.merge(upload_params)

        # 4. Call appropriate SM client endpoint
        client_response = create_client_response(message, message_params_h, create_message_params)

        # 5. Log event
        UniqueUserEvents.log_event(
          user: current_user,
          event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT
        )

        # 6. Return serialized response
        options = build_response_options(client_response)
        render json: MessageSerializer.new(client_response, options)
      end

      def reply
        # Similar to create but use .as_reply
        message = Message.new(message_params.merge(upload_params)
          .merge(is_large_attachment_upload: use_large_attachment_upload)).as_reply
        raise Common::Exceptions::ValidationErrors, message unless message.valid?

        # ... rest similar to create
      end

      private

      def message_params
        @message_params ||= begin
          params[:message] = JSON.parse(params[:message]) if params[:message].is_a?(String)
          params.require(:message).permit(:draft_id, :category, :body, :recipient_id, :subject)
        end
      end

      def upload_params
        @upload_params ||= { uploads: params[:uploads] }
      end

      def use_large_attachment_upload
        return false unless any_file_too_large || total_size_too_large || total_file_count_too_large

        Flipper.enabled?(:mhv_secure_messaging_large_attachments) ||
          (Flipper.enabled?(:mhv_secure_messaging_cerner_pilot, @current_user) && oh_triage_group?)
      end

      def extend_timeout
        request.env['rack-timeout.timeout'] = Settings.mhv.sm.timeout
      end
    end
  end
end
```

### SM Client Usage Pattern

```ruby
# Initialize client with session
client = SM::Client.new(session: { user_id: current_user.mhv_correlation_id })

# Fetch messages
messages = client.get_messages(folder_id, page: 1, per_page: 10)

# Create message with attachments
params = {
  message: {
    category: 'GENERAL',
    subject: 'Test',
    body: 'Message body',
    recipient_id: 123
  },
  uploads: [file1, file2]
}

# Use appropriate endpoint based on attachment size
if use_large_attachments
  client.post_create_message_with_lg_attachments(params, poll_for_status: oh_triage_group?)
else
  client.post_create_message_with_attachment(params, poll_for_status: oh_triage_group?)
end
```

### Testing Pattern with VCR

```ruby
RSpec.describe 'MyHealth::V1::Messages', type: :request do
  let(:user) { build(:user, :mhv, mhv_correlation_id: '12345') }
  let(:message_id) { 573_059 }

  before do
    sign_in_as(user)
  end

  describe 'GET /my_health/v1/messaging/messages/:id' do
    it 'returns the message' do
      VCR.use_cassette('sm_client/messages/get_message_success') do
        get "/my_health/v1/messaging/messages/#{message_id}"

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('message')
      end
    end

    it 'returns 404 when message does not exist' do
      VCR.use_cassette('sm_client/messages/get_message_not_found') do
        get '/my_health/v1/messaging/messages/99999'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /my_health/v1/messaging/messages/:id/reply' do
    let(:attachment_type) { 'image/jpg' }
    let(:uploads) do
      [Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', attachment_type)]
    end

    let(:message_params) do
      { subject: 'RE: Test', body: 'Reply body', category: 'GENERAL' }
    end

    it 'creates a reply with attachments' do
      VCR.use_cassette('sm_client/messages/post_reply_with_attachment') do
        post "/my_health/v1/messaging/messages/#{message_id}/reply",
             params: { message: message_params, uploads: uploads }

        expect(response).to have_http_status(:created)
      end
    end
  end
end
```

### VSCode Snippets for SM Development

**Speed up development with built-in code snippets:**

#### `sm_client` - SM Client Call
Type `sm_client` + Tab to generate SM client initialization and method call:

```ruby
sm_client = SM::Client.new(session: { user_id: user.mhv_correlation_id })
response = sm_client.get_messages(params)
```

#### `sm_vcr` - SM Client with VCR
Type `sm_vcr` + Tab to generate VCR-wrapped SM client test:

```ruby
VCR.use_cassette('sm_client/endpoint') do
  sm_client = SM::Client.new(session: { user_id: user.mhv_correlation_id })
  response = sm_client.method(params)
  # test assertions
end
```

**Common SM Client Methods:**
- `get_folder_messages(folder_id, page: 1)` - Get messages from folder
- `get_message(message_id)` - Get single message
- `post_create_message(params)` - Send message
- `post_create_message_draft(params)` - Create draft

#### `flipper_stub` - Feature Flag Stub
Type `flipper_stub` + Tab to correctly stub Flipper in tests (never use `Flipper.enable!`):

```ruby
allow(Flipper).to receive(:enabled?).with(:feature_name).and_return(true)
```

---

## ⚙️ Feature Flags

### Secure Messaging Feature Flags

**`:mhv_secure_messaging_large_attachments`**
- Enables large attachment uploads (up to 25 MB per file, 10 files total)
- Used globally when enabled

**`:mhv_secure_messaging_cerner_pilot`**
- Enables large attachments specifically for Cerner pilot users
- Used in combination with `oh_triage_group?` check
- User-specific flag

**Usage Pattern:**
```ruby
def use_large_attachment_upload
  return false unless any_file_too_large || total_size_too_large || total_file_count_too_large

  Flipper.enabled?(:mhv_secure_messaging_large_attachments) ||
    (Flipper.enabled?(:mhv_secure_messaging_cerner_pilot, @current_user) && oh_triage_group?)
end
```

**In Tests:**
```ruby
# ALWAYS stub, never enable/disable
allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_large_attachments).and_return(true)
allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, user).and_return(false)
```

---

## 🔐 Authentication & Authorization

### Authorization Policy (`app/policies/mhv_messaging_policy.rb`)

The `MHVMessagingPolicy` controls access to Secure Messaging features using a Struct-based policy pattern:

```ruby
MHVMessagingPolicy = Struct.new(:user, :mhv_messaging) do
  def access?
    return false unless user.mhv_correlation_id
    return false if Flipper.enabled?(:mhv_secure_messaging_policy_va_patient) && !user.va_patient?

    client = SM::Client.new(session: { user_id: user.mhv_correlation_id, user_uuid: user.uuid })
    validate_client(client)
  end

  def mobile_access?
    return false unless user.mhv_correlation_id && user.va_patient?

    client = Mobile::V0::Messaging::Client.new(session: { user_id: user.mhv_correlation_id, user_uuid: user.uuid })
    validate_client(client)
  end

  private

  def validate_client(client)
    if client.session.expired?
      client.authenticate
      !client.session.expired?
    else
      true
    end
  rescue
    log_denial_details
    false
  end
end
```

**Access Requirements:**
1. **MHV Correlation ID:** User must have `mhv_correlation_id`
2. **VA Patient Status:** If `:mhv_secure_messaging_policy_va_patient` feature flag is enabled, user must be a VA patient
3. **Valid MHV Session:** SM::Client session must be valid or successfully authenticate

**Feature Flag:**
- **`:mhv_secure_messaging_policy_va_patient`** - When enabled, restricts access to VA patients only

**Usage in Controllers:**
```ruby
# In SMController
def authorize
  raise_access_denied unless current_user.authorize(:mhv_messaging, :access?)
end
```

### MHV Session Management

**All SM controllers inherit from `SMController`:**
```ruby
module MyHealth
  class SMController < ApplicationController
    include MyHealth::MHVControllerConcerns
    include JsonApiPaginationLinks
    service_tag 'mhv-messaging'

    protected

    def client
      @client ||= SM::Client.new(
        session: { user_id: current_user.mhv_correlation_id, user_uuid: current_user.uuid }
      )
    end

    def authorize
      raise_access_denied unless current_user.authorize(:mhv_messaging, :access?)
    end

    def raise_access_denied
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to messaging'
    end
  end
end
```

**Key Points:**
- User must have MHV correlation ID (`current_user.mhv_correlation_id`)
- Authorization check happens via `MHVMessagingPolicy#access?`
- Session is passed to SM::Client with both `user_id` and `user_uuid`
- Client handles MHV API authentication internally
- Session validation includes expiration checks and automatic re-authentication

---

## 📝 Error Handling

### Common Error Scenarios

**Validation Errors:**
```ruby
raise Common::Exceptions::ValidationErrors, message unless message.valid?
# Returns 422 Unprocessable Entity with validation errors
```

**Record Not Found:**
```ruby
raise Common::Exceptions::RecordNotFound, message_id if response.blank?
# Returns 404 Not Found
```

**MHV API Errors:**
```ruby
rescue Faraday::TimeoutError => e
  Rails.logger.error("MHV SM: Timeout for user #{current_user.icn}")
  render json: { error: { code: 'MHV_TIMEOUT', message: 'Service temporarily unavailable' } },
         status: :gateway_timeout

rescue Faraday::ClientError => e
  Rails.logger.error("MHV SM: Client error - #{e.message}")
  render json: { error: { code: 'MHV_ERROR', message: 'Unable to process request' } },
         status: :bad_gateway
```

**Never Log PII:**
- ❌ Don't log: `user.email`, `user.ssn`, message body, message subject
- ✅ Do log: `user.icn`, message ID, folder ID, error types

---

## 🧪 Testing Guidelines

### Test Structure for SM Features

**Request Specs:**
- Location: `modules/my_health/spec/requests/my_health/v1/`
- Use VCR cassettes for SM client responses
- Test all HTTP status codes: 200, 201, 404, 422, 503
- Test authentication requirements
- Test validation failures

**Model Specs:**
- Location: `spec/models/`
- Test all validation scenarios
- Test file upload limits (standard and large)
- Test `as_reply` behavior

**Client Specs:**
- Location: `spec/lib/sm/client/`
- Test individual SM::Client methods
- Use VCR cassettes for MHV API responses

### VCR Cassette Naming Convention

```
spec/fixtures/vcr_cassettes/sm_client/
  ├── session/
  │   └── mhv_session.yml
  ├── messages/
  │   ├── get_messages_success.yml
  │   ├── get_message_success.yml
  │   ├── get_message_not_found.yml
  │   ├── post_create_message.yml
  │   └── post_create_message_with_attachment.yml
  ├── folders/
  │   └── get_folders.yml
  └── triage_teams/
      └── get_triage_teams.yml
```

---

## 📊 Monitoring & Logging

### Datadog Tracing (Recommended Addition)

```ruby
def create
  Datadog::Tracing.trace('mhv.secure_messaging.create_message') do |span|
    span.set_tag('user.icn', current_user.icn)
    span.set_tag('message.category', message_params[:category])
    span.set_tag('attachments.count', upload_params[:uploads]&.length || 0)
    span.set_tag('attachments.large_upload', use_large_attachment_upload)

    # ... method logic ...
  end
end
```

### StatsD Metrics

The SM::Client automatically tracks:
- `api.sm.get_messages` - Message retrieval
- `api.sm.post_create_message` - Message creation
- `api.sm.post_create_message_reply` - Reply creation

---

## 🚨 Common Issues & Solutions

### Issue: Validation fails with "Total file count exceeds 4 files"
**Solution:** Check if large attachment feature flags are enabled and `is_large_attachment_upload` is set correctly.

### Issue: VCR cassette not found in tests
**Solution:** Verify cassette path matches naming convention. May need to record new cassette by temporarily allowing HTTP connections.

### Issue: MHV session timeout
**Solution:** SM::Client handles session refresh automatically. If issues persist, check MHV API status.

### Issue: Message body contains HTML
**Solution:** Message model strips HTML in `initialize` using Nokogiri. Body is sanitized automatically.

### Issue: OH triage group timeouts
**Solution:** Use `extend_timeout` before_action for create/reply actions when `oh_triage_group?` is true.

---

## 📖 Additional Resources

For general vets-api patterns and guidelines, see:
- [.github/copilot-instructions.md](../copilot-instructions.md) - General repository patterns
- [.vscode/copilot-examples.md](../../.vscode/copilot-examples.md) - Code examples
- [.vscode/DEVELOPMENT_GUIDELINES.md](../../.vscode/DEVELOPMENT_GUIDELINES.md) - Development patterns

---

## 📄 OpenAPI Documentation

### Location and Structure

**OpenAPI specs for Secure Messaging are located in:**
- `modules/my_health/docs/openapi.yaml` - Main spec file with endpoint definitions
- `modules/my_health/docs/schemas/` - Individual schema files for request/response models
- `modules/my_health/docs/openapi_merged.yaml` - Generated merged file (served by API)

**Key Schema Files:**
- `SecureMessageDetail.yml` - Single message response
- `SecureMessageList.yml` - Message collection response
- `SecureMessageSummary.yml` - Message summary (in lists)
- `SecureMessageListInThread.yml` - Thread message response
- `SecureMessageNewMessageRequest.yml` - Create message request
- `SecureMessageReplyRequest.yml` - Reply message request
- `SecureMessagingFolder.yml` - Single folder response
- `SecureMessagingFolders.yml` - Folder collection response
- `SecureMessagingRecipients.yml` - Triage teams (patient's assigned)
- `SecureMessagingAllRecipients.yml` - All triage teams
- `SecureMessageCategories.yml` - Message categories
- `SecureMessageSignature.yml` - User signature
- `SecureMessageAttachment.yml` - Attachment metadata
- `SecureMessageThread.yml` - Thread structure
- `SecureMessageSearch.yml` - Search results
- `SecureMessagingUpdateTriageTeamRequest.yml` - Preference update request

### Updating OpenAPI Docs

**When to update OpenAPI specs:**
- Adding new endpoints to SM controllers
- Changing request/response formats
- Adding/removing/modifying parameters
- Changing status codes or error responses
- Adding new schemas or updating existing ones

**Update workflow:**

1. **Edit the spec files:**
   ```bash
   # Edit main spec for endpoint changes
   vi modules/my_health/docs/openapi.yaml

   # Edit schema files for model changes
   vi modules/my_health/docs/schemas/SecureMessage*.yml
   ```

2. **Regenerate merged spec (REQUIRED for PR):**
   ```bash
   # Install redocly if not already installed
   npm install @redocly/cli -g

   # Generate merged file
   cd modules/my_health/docs
   sh merge_api_docs.sh
   ```

3. **Generate HTML docs for local review (optional):**
   ```bash
   # Install redoc-cli if not already installed
   npm install redoc-cli -g

   # Generate HTML
   sh generate_html_docs.sh

   # Open in browser
   open index.html
   ```

4. **Commit both files:**
   ```bash
   git add modules/my_health/docs/openapi.yaml
   git add modules/my_health/docs/openapi_merged.yaml
   # Also add any schema files you modified
   ```

**Important:** Always regenerate `openapi_merged.yaml` after editing `openapi.yaml` or schema files, as the merged file is what's served by the `ApidocsController`.

### API Docs Endpoint

OpenAPI specs are served via:
- **Controller:** `modules/my_health/app/controllers/my_health/apidocs_controller.rb`
- **Endpoint:** `GET /my_health/apidocs` (returns JSON of merged spec)
- **Source file:** `modules/my_health/docs/openapi_merged.yaml`

### Common OpenAPI Patterns for SM

**Message endpoint example:**
```yaml
/v1/messaging/messages:
  post:
    description: Create a new secure message
    operationId: create_message
    requestBody:
      content:
        multipart/form-data:
          schema:
            $ref: ./schemas/SecureMessageNewMessageRequest.yml
    responses:
      '201':
        content:
          application/json:
            schema:
              $ref: ./schemas/SecureMessageDetail.yml
      '422':
        description: Validation error
```

**Schema reference pattern:**
```yaml
# In openapi.yaml
$ref: ./schemas/SecureMessageDetail.yml

# Schema files use relative references
# In SecureMessageDetail.yml
properties:
  data:
    $ref: ./SecureMessageSummary.yml
```

---

## 🔄 Maintaining These Instructions

### When to Update This File

**This instruction file should be updated when changes to `applyTo` files impact:**
- API contracts (request/response formats, endpoints, parameters)
- Controller patterns (before_actions, error handling, common patterns)
- Model validations or attributes
- Client methods or signatures
- Serializer structure or attributes
- Route definitions
- Feature flag usage patterns
- Authentication/authorization requirements
- Testing patterns specific to Secure Messaging

**Analyze changes for impact:**
1. **New endpoints or actions** → Update Routes section, Controller examples, and OpenAPI Documentation
2. **New models or attributes** → Update Models section with new validations/attributes and OpenAPI schemas
3. **New SM::Client methods** → Update Client Library section with method signatures
4. **New serializers or attributes** → Update Serializers section and corresponding OpenAPI schema files
5. **New feature flags** → Update Feature Flags section with usage patterns
6. **Changed validation rules** → Update Models section and testing examples
7. **Changed error handling** → Update Error Handling section and OpenAPI response codes
8. **New controller patterns** → Update Common Patterns section with examples
9. **Authentication changes** → Update Authentication & Authorization section
10. **Changed file upload limits** → Update Message Model section and OpenAPI request schemas
11. **Changed request/response formats** → Update OpenAPI schemas and regenerate merged spec

**Changes that DON'T require updates:**
- Internal implementation details that don't affect usage patterns
- Refactoring that maintains the same public interface
- Bug fixes that don't change behavior
- Performance optimizations without API changes
- Code style or formatting changes

**How to Keep Instructions Current:**
- Review this file when making significant changes to Secure Messaging features
- Update code examples to match current patterns in the codebase
- Remove deprecated patterns and add new best practices
- Keep VCR cassette examples aligned with actual test structure
- Verify feature flag documentation matches current implementation

---

**These path-specific instructions automatically apply when working on My Health/Secure Messaging features.**
