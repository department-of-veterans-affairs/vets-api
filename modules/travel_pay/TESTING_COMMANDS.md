# Test commands you can run to verify the Complex Claims Form Progress API

## 1. Rails Console Testing (Recommended)
# Start console: bundle exec rails console

# Basic model testing:
session = TravelPay::ComplexClaimsFormSession.find_or_create_for_user('123456789V987654321')
puts "Session created: #{session.id}"

# Test form step updates:
session.update_form_step('parking', 1, started: true, complete: false)
session.update_form_step('parking', 2, started: true, complete: true)
session.update_form_step('mileage', 1, started: true, complete: false)

# Check the JSON output:
puts JSON.pretty_generate(session.to_progress_json)

# Test individual choice methods:
parking_choice = session.complex_claims_form_choices.find_by(expense_type: 'parking')
parking_choice.mark_step_started(3)
parking_choice.mark_step_complete(1)
puts "Step 1 status: #{parking_choice.step_status(1)}"

# Test validation:
invalid_choice = session.complex_claims_form_choices.build(expense_type: 'invalid_type')
puts "Invalid choice valid? #{invalid_choice.valid?}"
puts "Validation errors: #{invalid_choice.errors.full_messages}"

## 2. Model Validation Testing
# Test expense type validation:
TravelPay::ComplexClaimsFormChoice.new(expense_type: 'invalid').valid?
TravelPay::ComplexClaimsFormChoice.new(expense_type: 'parking').valid?

# Test uniqueness validation:
session = TravelPay::ComplexClaimsFormSession.find_or_create_for_user('test-icn')
choice1 = session.complex_claims_form_choices.create!(expense_type: 'parking')
choice2 = session.complex_claims_form_choices.build(expense_type: 'parking')
puts "Duplicate choice valid? #{choice2.valid?}"

## 3. cURL Commands (when server is running)
# Note: You'll need proper authentication headers in real testing

# Get form progress:
curl -X GET http://localhost:3000/travel_pay/v1/complex_claims_form_progress \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json"

# Update a form step:
curl -X PATCH http://localhost:3000/travel_pay/v1/complex_claims_form_progress \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "progress": {
      "expense_type": "parking",
      "step_id": 1,
      "started": true,
      "complete": false
    }
  }'

# Bulk update:
curl -X PATCH http://localhost:3000/travel_pay/v1/complex_claims_form_progress/bulk_update \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
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
  }'

## 4. RSpec Testing
# Run specific tests for the feature:
bundle exec rspec spec/models/travel_pay/complex_claims_form_session_spec.rb
bundle exec rspec spec/models/travel_pay/complex_claims_form_choice_spec.rb
bundle exec rspec spec/controllers/travel_pay/v1/complex_claims_form_progress_controller_spec.rb

## 5. Database Inspection
# Check the tables were created correctly:
bundle exec rails db:console
# Then in PostgreSQL:
\d travel_pay_complex_claims_form_sessions
\d travel_pay_complex_claims_form_choices
SELECT * FROM travel_pay_complex_claims_form_sessions;

## 6. Routes Testing
# Verify routes are properly configured:
bundle exec rails routes | grep complex_claims_form_progress

## 7. Quick Smoke Test Script
# Create this as a Ruby script to run: bundle exec rails runner test_script.rb

session = TravelPay::ComplexClaimsFormSession.find_or_create_for_user('smoke-test-icn')
puts "✓ Session created successfully"

session.update_form_step('parking', 1, started: true, complete: false)
session.update_form_step('toll', 2, started: true, complete: true)
puts "✓ Form steps updated successfully"

progress = session.to_progress_json
puts "✓ Progress JSON generated: #{progress[:choices].size} choices found"

parking_choice = session.complex_claims_form_choices.find_by(expense_type: 'parking')
status = parking_choice.step_status(1)
puts "✓ Step status retrieved: started=#{status[:started]}, complete=#{status[:complete]}"

puts "\n🎉 All smoke tests passed!"