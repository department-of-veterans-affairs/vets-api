# Travel Pay Expenses API

## Overview

The Travel Pay Expenses API allows users to submit various types of expenses related to their travel claims.

## Endpoint

```
POST /travel_pay/v0/claims/:claimId/expenses/:expenseType
```

### Parameters

- `claimId` (required): The UUID of the claim to attach the expense to
- `expenseType` (required): The type of expense. Valid values are:
  - `mileage` - Travel mileage expenses
  - `lodging` - Hotel/accommodation expenses  
  - `meal` - Food/meal expenses
  - `other` - Other miscellaneous expenses

### Request Body

```json
{
  "expense": {
    "purchase_date": "2024-01-15T10:30:00Z",
    "description": "Expense description",
    "cost_requested": 25.50,
    "receipt": "optional receipt data"
  }
}
```

### Required Fields

- `purchase_date`: Date/time when the expense was incurred (ISO 8601 format)
- `description`: Description of the expense (max 255 characters)
- `cost_requested`: Amount requested for reimbursement (must be greater than 0)

### Optional Fields

- `receipt`: Receipt data/file associated with the expense

### Response

#### Success (201 Created)

```json
{
  "id": "12345678-1234-1234-1234-123456789012",
  "expense_type": "other",
  "claim_id": "87654321-4321-4321-4321-210987654321",
  "description": "Expense description",
  "cost_requested": 25.50,
  "purchase_date": "2024-01-15T10:30:00Z",
  "status": "created"
}
```

#### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": [
    {
      "title": "Unprocessable Entity",
      "detail": "Purchase date can't be blank, Cost requested can't be blank",
      "code": "422",
      "status": "422"
    }
  ]
}
```

#### Bad Request (400 Bad Request)

```json
{
  "errors": [
    {
      "title": "Bad request", 
      "detail": "Invalid expense type. Must be one of: mileage, lodging, meal, other",
      "code": "400",
      "status": "400"
    }
  ]
}
```

## Feature Flags

The endpoint requires the following feature flags to be enabled:
- `travel_pay_power_switch` - General travel pay access
- `travel_pay_complex_claims` - Complex claims functionality including expense submission

## Authentication

Requires valid VA.gov authentication token in the Authorization header:

```
Authorization: Bearer <token>
```

## Models and Validation

The endpoint uses the `TravelPay::BaseExpense` model for validation, which includes:

- Date/time validation for `purchase_date`
- Presence validation for required fields
- Length validation for description (max 255 characters)
- Numeric validation for `cost_requested` (must be > 0)

## Example Usage

```bash
curl -X POST "https://api.va.gov/travel_pay/v0/claims/12345678-1234-1234-1234-123456789012/expenses/meal" \
  -H "Authorization: Bearer your_token_here" \
  -H "Content-Type: application/json" \
  -d '{
    "expense": {
      "purchase_date": "2024-01-15T12:00:00Z",
      "description": "Lunch during medical appointment",
      "cost_requested": 15.75
    }
  }'
```

## Future Enhancements

- Specific expense models for each type (MileageExpense, LodgingExpense, MealExpense)
- Receipt file upload functionality
- Integration with existing travel pay expense processing systems
- Additional validation rules per expense type

## Technical Implementation

### Generic Expense Client

The `TravelPay::ExpensesClient` now includes a generic `add_expense` method that can handle different expense types:

```ruby
client.add_expense(veis_token, btsss_token, expense_type, request_body)
```

#### Endpoint Routing

The client automatically routes to the appropriate endpoint based on expense type:

- `mileage` → `api/v2/expenses/mileage`
- `lodging` → `api/v2/expenses/lodging`
- `meal` → `api/v2/expenses/meal`
- `other` → `api/v2/expenses/other`
- Unknown types → `api/v2/expenses` (generic endpoint)

#### Request Body Format

The generic method accepts a flexible request body format:

```ruby
{
  'claimId' => 'claim-uuid',
  'dateIncurred' => '2024-01-15T10:30:00Z',
  'description' => 'Expense description',
  'amount' => 25.50,
  'expenseType' => 'meal'
}
```

This provides a consistent interface while allowing for expense-type-specific customizations in the future.
