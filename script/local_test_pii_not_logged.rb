#!/usr/bin/env ruby
# frozen_string_literal: true

# Run this to test that PII (email, first_name) is not logged when jobs run.
#
# 1. Start app + Sidekiq in another terminal:
#    foreman start -f Procfile.dev
#    (or: bundle exec rails s & bundle exec sidekiq -q default,2)
#
# 2. Run this script:
#    bundle exec rails runner script/local_test_pii_not_logged.rb
#
# 3. Watch the terminal where Sidekiq is running. You should NOT see
#    "pii-test-no-log@example.com" or "PiiTestFirst" in the output.
#
# 4. Optional: To test retries_exhausted logging, enqueue a job that will
#    fail and retry until exhausted, then check logs (or use the RSpec examples).

require 'debt_management_center/sidekiq/va_notify_email_job'

TEST_EMAIL = 'pii-test-no-log@example.com'
TEST_FIRST_NAME = 'PiiTestFirst'

puts "Enqueuing DebtManagementCenter::VANotifyEmailJob with test PII..."
puts "  email: #{TEST_EMAIL}"
puts "  first_name: #{TEST_FIRST_NAME}"
puts ""
puts "Watch your Sidekiq terminal. These values should NOT appear in any log line."
puts ""

DebtManagementCenter::VANotifyEmailJob.perform_async(
  TEST_EMAIL,
  'test-template-id',
  { 'first_name' => TEST_FIRST_NAME, 'date_submitted' => Time.zone.now.strftime('%m/%d/%Y') },
  { 'id_type' => 'email' }
)

puts "Job enqueued. Check Sidekiq output and log files (log/development.log) for any occurrence of:"
puts "  - #{TEST_EMAIL}"
puts "  - #{TEST_FIRST_NAME}"
puts ""
puts "If you see them in logs, the middleware or job logging needs to be fixed."
