#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick smoke test for Complex Claims Form Progress API
# Run with: bundle exec rails runner smoke_test.rb

puts '🚀 Starting Complex Claims Form Progress Smoke Test...'

begin
  # Test 1: Create session
  puts "\n1️⃣ Testing session creation..."
  session = TravelPay::ComplexClaimsFormSession.find_or_create_for_user('smoke-test-icn-123')
  puts "   ✓ Session created with ID: #{session.id}"

  # Test 2: Update form steps
  puts "\n2️⃣ Testing form step updates..."
  session.update_form_step('parking', 1, started: true, complete: false)
  session.update_form_step('parking', 2, started: true, complete: true)
  session.update_form_step('mileage', 1, started: true, complete: false)
  session.update_form_step('toll', 1, started: false, complete: false)
  puts '   ✓ Form steps updated successfully'

  # Test 3: Generate progress JSON
  puts "\n3️⃣ Testing progress JSON generation..."
  progress = session.to_progress_json
  puts "   ✓ Progress JSON generated with #{progress[:choices].size} choices"
  puts '   📋 Progress data:'
  progress[:choices].each do |choice|
    steps_count = choice[:formProgress].size
    completed_count = choice[:formProgress].count { |step| step['complete'] }
    puts "      - #{choice[:expenseType]}: #{completed_count}/#{steps_count} steps complete"
  end

  # Test 4: Individual choice methods
  puts "\n4️⃣ Testing individual choice methods..."
  parking_choice = session.complex_claims_form_choices.find_by(expense_type: 'parking')
  parking_choice.mark_step_started(3)
  parking_choice.mark_step_complete(4)
  status = parking_choice.step_status(1)
  puts "   ✓ Choice methods working: step 1 started=#{status[:started]}, complete=#{status[:complete]}"

  # Test 5: Validation
  puts "\n5️⃣ Testing validations..."
  invalid_choice = session.complex_claims_form_choices.build(expense_type: 'invalid_type')
  if invalid_choice.valid?
    puts '   ❌ Validation failed: invalid expense type was accepted'
  else
    puts '   ✓ Validation working: invalid expense type rejected'
  end

  # Test 6: Uniqueness constraint
  puts "\n6️⃣ Testing uniqueness constraint..."
  duplicate_choice = session.complex_claims_form_choices.build(expense_type: 'parking')
  if duplicate_choice.valid?
    puts '   ❌ Uniqueness constraint failed: duplicate was accepted'
  else
    puts '   ✓ Uniqueness constraint working: duplicate expense type rejected'
  end

  # Test 7: Final JSON output
  puts "\n7️⃣ Testing final JSON output..."
  final_json = session.to_progress_json
  if final_json.is_a?(Hash) && final_json.key?(:choices)
    puts '   ✓ JSON output has correct structure'
  else
    puts '   ❌ JSON output structure incorrect'
  end

  puts "\n🎉 All smoke tests completed successfully!"
  puts "\n📊 Final session state:"
  puts JSON.pretty_generate(session.to_progress_json)
rescue => e
  puts "\n❌ Smoke test failed with error:"
  puts "   #{e.class}: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  exit 1
end
