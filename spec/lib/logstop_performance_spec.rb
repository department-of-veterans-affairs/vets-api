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
end
# rubocop:enable RSpec/DescribeClass
