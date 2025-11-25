#!/usr/bin/env ruby
# frozen_string_literal: true

# Logstop Performance Benchmark
# Run with: ruby Research/docs/logstop-performance-benchmark.rb

require 'benchmark'
require 'logstop'

# Sample log messages (realistic vets-api logs)
SAMPLE_LOGS = [
  'Processing ClaimsController#index',
  'User authenticated successfully user_uuid=abc-123-def claim_id=600123456',
  'GET /v0/user 200 OK duration=45ms',
  'Sidekiq job ClaimStatusWorker started claim_id=600123456 timestamp=1732478261',
  'External API response status=200 body={"data":{"id":"12345","type":"claim"},"meta":{"count":1}}',
  'SQL query executed in 12ms SELECT * FROM users WHERE id = 12345',
  'Cache hit for key veterans_profile_abc123 ttl=3600',
  'Failed to fetch benefits info error="Connection timeout" user_account_uuid=abc-123-def',
  'PDF generation completed file_size=245678 pages=12 duration=234ms',
  'Datadog metrics pushed success=true count=45 tags=["env:production","service:vets-api"]'
].freeze

# VA custom scrubber from the PR
va_custom_scrubber = lambda do |msg|
  # First apply Logstop's built-in patterns (SSN, email, phone, credit cards)
  msg = Logstop.scrub(msg)

  # VA file numbers
  msg = msg.gsub(/\bVA\s*(?:file\s*)?(?:number|#|no\.?)?:?\s*(\d{8,9})\b/i,
                 'VA file number: [VA_FILE_NUMBER_FILTERED]')

  # Standalone 9-digit numbers (SSN without dashes)
  msg = msg.gsub(/\b(?<!\d)(\d{9})(?!\d)\b/, '[SSN_FILTERED]')

  # EDIPI (10 digit DoD identifier)
  msg = msg.gsub(/\b(?<!\d)(\d{10})(?!\d)\b/, '[EDIPI_FILTERED]')

  msg
end

# Benchmark configuration
ITERATIONS = 10_000

puts "Logstop Performance Benchmark"
puts "=" * 80
puts "Iterations per test: #{ITERATIONS}"
puts "Sample log messages: #{SAMPLE_LOGS.size}"
puts "=" * 80
puts

# Test 1: Baseline - no filtering
puts "Test 1: Baseline (no filtering)"
baseline_time = Benchmark.realtime do
  ITERATIONS.times do
    SAMPLE_LOGS.each do |msg|
      msg.dup # Simulate string handling
    end
  end
end
puts "  Time: #{(baseline_time * 1000).round(2)}ms"
puts "  Per log line: #{((baseline_time / (ITERATIONS * SAMPLE_LOGS.size)) * 1_000_000).round(2)}µs"
puts

# Test 2: Logstop built-in only
puts "Test 2: Logstop built-in patterns only"
logstop_time = Benchmark.realtime do
  ITERATIONS.times do
    SAMPLE_LOGS.each do |msg|
      Logstop.scrub(msg)
    end
  end
end
puts "  Time: #{(logstop_time * 1000).round(2)}ms"
puts "  Per log line: #{((logstop_time / (ITERATIONS * SAMPLE_LOGS.size)) * 1_000_000).round(2)}µs"
puts "  Overhead vs baseline: #{((logstop_time / baseline_time - 1) * 100).round(2)}%"
puts

# Test 3: VA custom scrubber (Logstop + VA patterns)
puts "Test 3: VA custom scrubber (Logstop + 3 regex patterns)"
custom_time = Benchmark.realtime do
  ITERATIONS.times do
    SAMPLE_LOGS.each do |msg|
      va_custom_scrubber.call(msg)
    end
  end
end
puts "  Time: #{(custom_time * 1000).round(2)}ms"
puts "  Per log line: #{((custom_time / (ITERATIONS * SAMPLE_LOGS.size)) * 1_000_000).round(2)}µs"
puts "  Overhead vs baseline: #{((custom_time / baseline_time - 1) * 100).round(2)}%"
puts "  Overhead vs Logstop-only: #{((custom_time / logstop_time - 1) * 100).round(2)}%"
puts

# Test 4: Large payload simulation
puts "Test 4: Large JSON payload (5KB)"
large_payload = '{"data":' + ('{"id":"12345","type":"claim","attributes":{"status":"pending"}},' * 100) + '}'
large_iterations = 1000

large_baseline = Benchmark.realtime do
  large_iterations.times { large_payload.dup }
end

large_filtered = Benchmark.realtime do
  large_iterations.times { va_custom_scrubber.call(large_payload) }
end

puts "  Baseline: #{(large_baseline * 1000).round(2)}ms"
puts "  Filtered: #{(large_filtered * 1000).round(2)}ms"
puts "  Per payload: #{((large_filtered / large_iterations) * 1000).round(2)}ms"
puts "  Overhead: #{((large_filtered / large_baseline - 1) * 100).round(2)}%"
puts

# Summary
puts "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "Expected overhead per log line: #{((custom_time / (ITERATIONS * SAMPLE_LOGS.size)) * 1_000_000).round(2)}µs"
puts "Expected overhead for 1M logs/day: #{((custom_time / baseline_time - 1) * 100).round(2)}% increase"
puts
puts "Recommendations:"
if (custom_time / baseline_time - 1) * 100 < 5
  puts "  ✓ LOW IMPACT: <5% overhead is acceptable for security benefit"
elsif (custom_time / baseline_time - 1) * 100 < 15
  puts "  ⚠ MODERATE IMPACT: Consider opt-in approach or feature flag"
else
  puts "  ✗ HIGH IMPACT: >15% overhead - strongly recommend opt-in only"
end
puts
puts "Note: Run this on staging with realistic load to validate results"
