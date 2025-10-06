# Travel Pay Complex Claims Form Progress API

This implementation provides endpoints to track user progress through Travel Pay complex claims forms, allowing persistent state management for multi-step expense forms.

## Database Schema

### Tables Created

#### `travel_pay_complex_claims_form_sessions`
- `id` (Primary Key)
- `user_icn` (String, Not Null) - Veteran's ICN for identity
- `metadata` (JSONB, Default: {}) - Additional session metadata
- `created_at`, `updated_at` (Timestamps)

**Indexes:**
- `user_icn` (for efficient user lookups)
- `created_at` (for performance)

#### `travel_pay_complex_claims_form_choices`
- `id` (Primary Key)
- `travel_pay_complex_claims_form_session_id` (Foreign Key)
- `expense_type` (String, Not Null) - Type of expense (mileage, parking, toll)
- `form_progress` (JSONB, Default: []) - Array of form step progress
- `created_at`, `updated_at` (Timestamps)

**Indexes:**
- Unique composite index on `travel_pay_complex_claims_form_session_id` + `expense_type`

## API Endpoints

### Base URL
All endpoints are prefixed with `/travel_pay/v1/`

### 1. Get Complex Claims Form Progress
**GET** `/complex_claims_form_progress`

Returns the current complex claims form progress for the authenticated user.

**Response:**
```json
{
  "choices": [
    {
      "expenseType": "parking",
      "formProgress": [
        { "id": 1, "started": true, "complete": true },
        { "id": 2, "started": true, "complete": false }
      ]
    },
    {
      "expenseType": "toll",
      "formProgress": [
        { "id": 3, "started": false, "complete": false }
      ]
    }
  ]
}
```

### 2. Update Single Complex Claims Form Step
**PATCH** `/complex_claims_form_progress`

Updates a single form step for a specific expense type.

**Request Body:**
```json
{
  "progress": {
    "expense_type": "parking",
    "step_id": 2,
    "started": true,
    "complete": true
  }
}
```

**Response:** Same as GET `/complex_claims_form_progress`

### 3. Bulk Update Multiple Steps
**PATCH** `/complex_claims_form_progress/bulk_update`

Updates multiple form steps in a single request.

**Request Body:**
```json
{
  "bulk_progress": {
    "updates": [
      {
        "expense_type": "parking",
        "step_id": 1,
        "started": true,
        "complete": true
      },
      {
        "expense_type": "mileage",
        "step_id": 1,
        "started": true,
        "complete": false
      }
    ]
  }
}
```

**Response:** Same as GET `/complex_claims_form_progress`

## Models

### TravelPay::ComplexClaimsFormSession
Main session model that tracks overall complex claims form progress for a user.

**Key Methods:**
- `find_or_create_for_user(user_icn)` - Finds or creates session for user
- `to_progress_json` - Returns formatted progress data
- `update_form_step(expense_type, step_id, started:, complete:)` - Updates specific step

### TravelPay::ComplexClaimsFormChoice
Tracks progress for individual expense types within a complex claims session.

**Key Methods:**
- `update_form_step(step_id, started:, complete:)` - Updates step progress
- `mark_step_started(step_id)` - Convenience method to mark step as started
- `mark_step_complete(step_id)` - Convenience method to mark step as complete
- `step_status(step_id)` - Returns current status of a step

**Validations:**
- Expense type must be one of: `mileage`, `parking`, `toll`
- Unique expense type per session

## Usage Examples

### JavaScript Frontend Integration

```javascript
// Get current complex claims form progress
const getComplexClaimsFormProgress = async () => {
  const response = await fetch('/travel_pay/v1/complex_claims_form_progress', {
    headers: { 'Authorization': 'Bearer ' + token }
  });
  return response.json();
};

// Mark a step as started
const startComplexClaimsFormStep = async (expenseType, stepId) => {
  await fetch('/travel_pay/v1/complex_claims_form_progress', {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    },
    body: JSON.stringify({
      progress: {
        expense_type: expenseType,
        step_id: stepId,
        started: true,
        complete: false
      }
    })
  });
};

// Complete a step
const completeComplexClaimsFormStep = async (expenseType, stepId) => {
  await fetch('/travel_pay/v1/complex_claims_form_progress', {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    },
    body: JSON.stringify({
      progress: {
        expense_type: expenseType,
        step_id: stepId,
        started: true,
        complete: true
      }
    })
  });
};
```

### Ruby Console Examples

```ruby
# Find or create a session for a user
session = TravelPay::ComplexClaimsFormSession.find_or_create_for_user('123456789V987654321')

# Update a form step directly
session.update_form_step('parking', 1, started: true, complete: false)

# Get progress data
progress = session.to_progress_json
# => {
#   choices: [
#     {
#       expenseType: 'parking',
#       formProgress: [{ id: 1, started: true, complete: false }]
#     }
#   ]
# }

# Work with individual choices
choice = session.complex_claims_form_choices.find_by(expense_type: 'mileage')
choice.mark_step_started(2)
choice.mark_step_complete(1)
```

## Security Features

- **Authentication Required:** All endpoints require user authentication
- **ICN-based:** Uses veteran's ICN for identity (required for VA integrations)
- **Feature Flag Protected:** Inherits travel_pay_power_switch feature flag protection
- **Error Handling:** Comprehensive error responses with proper HTTP status codes

## Database Performance

- **Concurrent Indexes:** All indexes created with `algorithm: :concurrently`
- **JSONB Storage:** Efficient storage and querying of form progress arrays
- **Unique Constraints:** Prevents duplicate expense type entries per session

## Files Created/Modified

### Database Migrations
- `db/migrate/20251003184819_create_complex_claims_form_tables.rb` - Creates complex claims form tables

### Models
- `modules/travel_pay/app/models/travel_pay/complex_claims_form_session.rb`
- `modules/travel_pay/app/models/travel_pay/complex_claims_form_choice.rb`

### Controllers
- `modules/travel_pay/app/controllers/travel_pay/v1/complex_claims_form_progress_controller.rb`

### Routes
- Updated `modules/travel_pay/config/routes.rb`

### Serializers
- `modules/travel_pay/app/serializers/travel_pay/complex_claims_form_progress_serializer.rb`
- `modules/travel_pay/app/serializers/travel_pay/complex_claims_form_session_serializer.rb`
- `modules/travel_pay/app/serializers/travel_pay/complex_claims_form_choice_serializer.rb`

## Testing

The implementation follows vets-api testing patterns:

```ruby
# Example test structure
RSpec.describe TravelPay::V1::ComplexClaimsFormProgressController, type: :controller do
  let(:user) { create(:user, :loa3) }
  
  before do
    sign_in_as(user)
    allow(Flipper).to receive(:enabled?).with(:travel_pay_power_switch, user).and_return(true)
  end

  describe 'GET #show' do
    it 'returns complex claims form progress' do
      get :show
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to have_key('choices')
    end
  end
end
```