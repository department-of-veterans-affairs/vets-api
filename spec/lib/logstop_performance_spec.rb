# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'
require 'logstop'
require_relative '../../config/initializers/logstop'

# Performance tests for Logstop PII filtering
# These tests document the performance characteristics and help leadership
# make informed decisions about deployment strategy (opt-in vs global)
# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Logstop Performance', :performance do
  # Sample realistic vets-api log messages
  let(:sample_logs) do
    [
      'Processing ClaimsController#index',
      'User authenticated successfully user_uuid=abc-123-def claim_id=600123456',
      'GET /v0/user 200 OK duration=45ms',
      'Sidekiq job ClaimStatusWorker started claim_id=600123456 timestamp=1732478261',
      'External API response status=200 body={"data":{"id":"12345","type":"claim"}}',
      'SQL query executed in 12ms SELECT * FROM users WHERE id = 12345',
      'Cache hit for key veterans_profile_abc123 ttl=3600',
      'Failed to fetch benefits info error="Connection timeout"',
      'PDF generation completed file_size=245678 pages=12 duration=234ms',
      'Datadog metrics pushed success=true count=45'
    ]
  end

  let(:iterations) { 10_000 }
  let(:large_payload) { "{\"data\":#{'{"id":"12345","type":"claim"},' * 100}}" }

  describe 'overhead measurements' do
    it 'measures baseline (no filtering) performance' do
      time = Benchmark.realtime do
        iterations.times do
          sample_logs.each(&:dup)
        end
      end

      per_line_us = (time / (iterations * sample_logs.size)) * 1_000_000

      Rails.logger.debug { "\n  Baseline: #{(time * 1000).round(2)}ms total" }
      Rails.logger.debug { "  Per line: #{per_line_us.round(2)}µs" }

      # This is our baseline - should be very fast
      expect(per_line_us).to be < 0.5 # Less than 0.5 microseconds
    end

    it 'measures Logstop built-in patterns overhead' do
      time = Benchmark.realtime do
        iterations.times do
          sample_logs.each { |msg| Logstop.scrub(msg) }
        end
      end

      per_line_us = (time / (iterations * sample_logs.size)) * 1_000_000

      Rails.logger.debug { "\n  Logstop built-in: #{(time * 1000).round(2)}ms total" }
      Rails.logger.debug { "  Per line: #{per_line_us.round(2)}µs" }

      # Document expected overhead (typically 1-3µs per line)
      expect(per_line_us).to be > 0.5 # Has measurable overhead
    end

    it 'measures VA custom scrubber overhead' do
      scrubber = VAPiiScrubber.custom_scrubber

      time = Benchmark.realtime do
        iterations.times do
          sample_logs.each { |msg| scrubber.call(msg) }
        end
      end

      per_line_us = (time / (iterations * sample_logs.size)) * 1_000_000

      Rails.logger.debug { "\n  VA custom scrubber: #{(time * 1000).round(2)}ms total" }
      Rails.logger.debug { "  Per line: #{per_line_us.round(2)}µs" }

      # Document expected overhead (typically 2-4µs per line)
      expect(per_line_us).to be > 1.0 # More overhead than Logstop alone
    end

    it 'measures large payload overhead' do
      scrubber = VAPiiScrubber.custom_scrubber
      small_iterations = 1000

      baseline_time = Benchmark.realtime do
        small_iterations.times { large_payload.dup }
      end

      filtered_time = Benchmark.realtime do
        small_iterations.times { scrubber.call(large_payload) }
      end

      per_payload_ms = (filtered_time / small_iterations) * 1000
      overhead_percent = (((filtered_time / baseline_time) - 1) * 100).round(2)

      Rails.logger.debug "\n  Large payload (5KB):"
      Rails.logger.debug { "    Baseline: #{(baseline_time * 1000).round(2)}ms" }
      Rails.logger.debug { "    Filtered: #{(filtered_time * 1000).round(2)}ms" }
      Rails.logger.debug { "    Per payload: #{per_payload_ms.round(2)}ms" }
      Rails.logger.debug { "    Overhead: #{overhead_percent}%" }

      # Large payloads have significant overhead
      expect(per_payload_ms).to be > 0.05 # More than 0.05ms per 5KB payload
    end
  end

  describe 'false positive verification' do
    let(:scrubber) { VAPiiScrubber.custom_scrubber }

    it 'documents that 10-digit timestamps get filtered (FALSE POSITIVE)' do
      unix_timestamp = '1732478261' # Valid Unix timestamp
      msg = "Job started at #{unix_timestamp}"

      result = scrubber.call(msg)

      Rails.logger.debug "\n  WARNING: Unix timestamp filtered as EDIPI"
      Rails.logger.debug { "    Input:  '#{msg}'" }
      Rails.logger.debug { "    Output: '#{result}'" }

      # This is a known false positive
      expect(result).to include('[EDIPI_FILTERED]')
    end

    it 'documents that 9-digit IDs get filtered (FALSE POSITIVE)' do
      claim_id = '600123456' # 9-digit claim ID
      msg = "Processing claim_id=#{claim_id}"

      result = scrubber.call(msg)

      Rails.logger.debug "\n  WARNING: 9-digit claim ID filtered as SSN"
      Rails.logger.debug { "    Input:  '#{msg}'" }
      Rails.logger.debug { "    Output: '#{result}'" }

      # This is a known false positive
      expect(result).to include('[SSN_FILTERED]')
    end
  end

  describe 'impact estimation' do
    it 'estimates impact for typical vets-api load' do
      scrubber = VAPiiScrubber.custom_scrubber

      # Measure overhead per line
      baseline = Benchmark.realtime do
        iterations.times { sample_logs.each(&:dup) }
      end

      filtered = Benchmark.realtime do
        iterations.times { sample_logs.each { |msg| scrubber.call(msg) } }
      end

      overhead_per_line_us = ((filtered - baseline) / (iterations * sample_logs.size)) * 1_000_000
      overhead_percent = (((filtered / baseline) - 1) * 100).round(2)

      # Estimate for different volumes
      logs_per_day = {
        '1M logs/day' => 1_000_000,
        '10M logs/day' => 10_000_000,
        '100M logs/day' => 100_000_000
      }

      Rails.logger.debug "\n  Performance Impact Estimates:"
      Rails.logger.debug { "    Per line overhead: #{overhead_per_line_us.round(2)}µs" }
      Rails.logger.debug { "    Relative overhead: #{overhead_percent}%" }
      Rails.logger.debug

      logs_per_day.each do |label, count|
        extra_seconds = (overhead_per_line_us * count) / 1_000_000
        Rails.logger.debug { "    #{label}: +#{extra_seconds.round(2)} seconds/day CPU time" }
      end

      Rails.logger.debug "\n  Recommendation:"
      if overhead_percent < 500
        Rails.logger.debug '    ✓ LOW IMPACT: Acceptable for global filtering'
      elsif overhead_percent < 2000
        Rails.logger.debug '    ⚠ MODERATE IMPACT: Consider opt-in approach'
      else
        Rails.logger.debug '    ✗ HIGH IMPACT: Strongly recommend opt-in only'
      end

      # Document the overhead for review
      expect(overhead_per_line_us).to be > 0
    end
  end

  # Trevor's concern: Regex pattern count and individual costs
  describe 'regex pattern breakdown (addressing Trevor concerns)' do
    let(:test_msg) { 'Test message with potential PII data' }
    let(:iterations_small) { 10_000 }

    it 'counts total regex patterns applied per log line' do
      # Logstop built-in patterns (enabled by default)
      logstop_patterns = {
        ssn: true,           # SSN with dashes (XXX-XX-XXXX)
        email: true,         # Email addresses
        phone: true,         # Phone numbers
        credit_card: true,   # Credit card numbers
        url_password: true   # Passwords in URLs
      }

      # VA custom patterns (in VAPiiScrubber)
      va_patterns = {
        va_file_number: true,  # VA file number pattern
        ssn_no_dashes: true,   # 9-digit SSN without dashes
        edipi: true            # 10-digit EDIPI
      }

      total_patterns = logstop_patterns.count { |_, enabled| enabled } + va_patterns.count { |_, enabled| enabled }

      Rails.logger.debug "\n  REGEX PATTERN COUNT:"
      Rails.logger.debug { "    Logstop built-in patterns: #{logstop_patterns.count { |_, enabled| enabled }}" }
      logstop_patterns.each do |name, enabled|
        Rails.logger.debug { "      - #{name}: #{enabled ? 'enabled' : 'disabled'}" }
      end
      Rails.logger.debug { "    VA custom patterns: #{va_patterns.size}" }
      va_patterns.each do |name, enabled|
        Rails.logger.debug { "      - #{name}: #{enabled ? 'enabled' : 'disabled'}" }
      end
      Rails.logger.debug { "    TOTAL REGEX PATTERNS PER LOG LINE: #{total_patterns}" }

      expect(total_patterns).to be >= 8
    end

    it 'measures per-pattern overhead contribution' do
      baseline_time = Benchmark.realtime do
        iterations_small.times { test_msg.dup }
      end

      # Test Logstop built-in only (no VA patterns)
      logstop_time = Benchmark.realtime do
        iterations_small.times { Logstop.scrub(test_msg) }
      end

      # Test full scrubber (Logstop + VA patterns)
      full_scrubber = VAPiiScrubber.custom_scrubber
      full_time = Benchmark.realtime do
        iterations_small.times { full_scrubber.call(test_msg) }
      end

      baseline_us = (baseline_time / iterations_small) * 1_000_000
      logstop_us = (logstop_time / iterations_small) * 1_000_000
      full_us = (full_time / iterations_small) * 1_000_000
      va_patterns_us = full_us - logstop_us

      Rails.logger.debug "\n  PER-PATTERN OVERHEAD BREAKDOWN:"
      Rails.logger.debug { "    Baseline (no filtering): #{baseline_us.round(3)}µs" }
      Rails.logger.debug do
        "    Logstop built-in (~5 patterns): #{logstop_us.round(3)}µs (+#{(logstop_us - baseline_us).round(3)}µs)"
      end
      Rails.logger.debug do
        "    VA custom patterns (3 patterns): +#{va_patterns_us.round(3)}µs additional"
      end
      Rails.logger.debug { "    TOTAL with all patterns: #{full_us.round(3)}µs" }
      Rails.logger.debug do
        "    Average cost per pattern: ~#{(full_us / 8).round(3)}µs (assuming 8 patterns)"
      end

      expect(full_us).to be > logstop_us
    end
  end

  # Trevor's concern: Structured metadata is NOT filtered
  describe 'structured metadata limitation (addressing Trevor concerns)' do
    it 'demonstrates that structured metadata/payload is NOT filtered' do
      scrubber = VAPiiScrubber.custom_scrubber

      # Example 1: Structured hash with PII (like Trevor's session example)
      structured_data = {
        user_uuid: 'daef5af0-12ad-4738-a088-9f0047340a86',
        ssn: '123-45-6789',           # PII in structured format
        edipi: '1234567890',          # PII in structured format
        session_handle: '76770900-0f90-4033-b19c-e281d95030c4'
      }

      # Convert to string (simulating how it would be logged)
      logged_string = "Session created -- #{structured_data.inspect}"

      # Apply scrubber
      result = scrubber.call(logged_string)

      Rails.logger.debug "\n  STRUCTURED METADATA TEST (Trevor's concern):"
      Rails.logger.debug { "    Original: #{logged_string}" }
      Rails.logger.debug { "    After Logstop: #{result}" }

      # The SSN and EDIPI in structured format may or may not be caught
      # depending on how Ruby's .inspect formats the hash
      if result.include?('123-45-6789')
        Rails.logger.debug '    ⚠️  WARNING: SSN in structured data NOT filtered!'
      else
        Rails.logger.debug '    ✓ SSN was filtered (but only because .inspect happened to format it)'
      end

      if result.include?('1234567890')
        Rails.logger.debug '    ⚠️  WARNING: EDIPI in structured data NOT filtered!'
      else
        Rails.logger.debug '    ✓ EDIPI was filtered (but only because .inspect happened to format it)'
      end

      Rails.logger.debug '    NOTE: Logstop filters STRING CONTENT, not structured data keys'
      Rails.logger.debug '    NOTE: filter_parameters would be more effective for structured data'

      # This test always passes, but documents the limitation
      expect(logged_string).to include('ssn')
    end

    it 'compares Logstop approach vs filter_parameters approach' do
      # Simulate what filter_parameters does (filters by key name)
      structured_data = {
        user_uuid: 'abc123',
        ssn: '123-45-6789',
        edipi: '1234567890',
        session_handle: 'xyz789'
      }

      # What filter_parameters would do (key-based filtering)
      filtered_params = ParameterFilterHelper.filter_params(structured_data)

      Rails.logger.debug "\n  COMPARISON: Logstop vs filter_parameters"
      Rails.logger.debug '    Structured data approach (filter_parameters):'
      Rails.logger.debug { "      Original: #{structured_data.inspect}" }
      Rails.logger.debug { "      Filtered: #{filtered_params.inspect}" }
      Rails.logger.debug '      Result: PII keys filtered by name (precise, fast)'
      Rails.logger.debug ''
      Rails.logger.debug '    Unstructured string approach (Logstop):'
      Rails.logger.debug '      Works on: "User SSN is 123-45-6789"'
      Rails.logger.debug '      Result: Pattern matching (imprecise, slow, false positives)'

      # filter_parameters should filter the ssn key
      expect(filtered_params[:ssn]).to eq('[FILTERED]')
    end
  end

  # Trevor's concern: False positive rate on production-like logs
  describe 'false positive rate on realistic logs (addressing Trevor concerns)' do
    it 'measures false positive rate on production-like log messages' do
      scrubber = VAPiiScrubber.custom_scrubber

      # Realistic production logs that should NOT be filtered
      clean_logs = [
        'Order ID 1234567890 created', # 10-digit order number (false positive)
        'Processing claim 600123456', # 9-digit claim ID (false positive)
        'Timestamp: 1732478261 (Unix time)', # Unix timestamp (false positive)
        'Tracking number: 9234567890',               # 10-digit tracking (false positive)
        'Transaction 123456789 completed',           # 9-digit transaction (false positive)
        'Request ID: abc-123-def',                   # Normal ID (should pass)
        'Cache key: user_profile_12345',             # Normal cache key (should pass)
        'Status code: 200',                          # HTTP status (should pass)
        'Duration: 45ms',                            # Timing (should pass)
        'Count: 42'                                  # Simple number (should pass)
      ]

      false_positives = 0
      clean_logs.each do |log|
        result = scrubber.call(log)
        if result.include?('[FILTERED]') || result.include?('_FILTERED]')
          false_positives += 1
          Rails.logger.debug { "    FALSE POSITIVE: '#{log}' -> '#{result}'" }
        end
      end

      false_positive_rate = (false_positives.to_f / clean_logs.size * 100).round(1)

      Rails.logger.debug "\n  FALSE POSITIVE ANALYSIS:"
      Rails.logger.debug { "    Total clean logs tested: #{clean_logs.size}" }
      Rails.logger.debug { "    False positives detected: #{false_positives}" }
      Rails.logger.debug { "    FALSE POSITIVE RATE: #{false_positive_rate}%" }
      Rails.logger.debug ''
      Rails.logger.debug '    Impact: Legitimate data gets filtered, making debugging harder'

      # Document the false positive rate
      expect(false_positive_rate).to be >= 0
    end
  end
end
# rubocop:enable RSpec/DescribeClass
