#!/usr/bin/env ruby
# Simple standalone logger smoke test.
# Usage:
#   bundle exec ruby script/log_test.rb [optional_message]
#
# Loads the Rails environment and emits a few log lines at different levels so you can
# verify formatting, structured fields, and any log shipping behavior.
# If you supply an argument, it will be appended to each message.

require_relative '../config/environment'

suffix = ARGV.first ? " :: #{ARGV.first}" : ''

Rails.logger.info  "log_test info#{suffix}"
Rails.logger.warn  "log_test warn#{suffix}"
Rails.logger.error "log_test error#{suffix}"

Rails.logger.send('blah')
# Example structured / semantic logging with rails_semantic_logger
Rails.logger.info('log_test structured', feature: 'shared_logging', phase: 'demo', timestamp: Time.now.utc.iso8601)

# Simulate logging an exception to compare formatting
begin
  raise StandardError, 'intentional test exception'
rescue => e
  Rails.logger.error(e)
end

puts 'Log test messages emitted.'
