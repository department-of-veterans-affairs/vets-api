#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to generate logging standardization guide for vets-api
# Usage: ruby generate_logging_guide.rb /path/to/vets-api

require 'find'
require 'json'

class LoggingGuideGenerator
  def initialize(root_path)
    @root_path = root_path
    @examples = Hash.new { |h, k| h[k] = [] }
  end

  def generate
    puts "📚 Generating logging standardization guide for: #{@root_path}"
    puts "=" * 80

    collect_examples
    create_markdown_guide
    create_rubocop_config

    puts "\n✅ Guide generation complete!"
  end

  private

  def collect_examples
    puts "\n🔍 Collecting real-world examples...\n"

    Find.find(@root_path) do |path|
      if FileTest.directory?(path)
        # Only skip build artifacts and vendor code
        if path.match?(%r{/(node_modules|tmp|log|coverage|\.git|vendor|public/packs)/})
          Find.prune
        else
          next
        end
      end

      next unless path.end_with?('.rb')
      next if path.include?('/spec/')

      collect_file_examples(path)
    end
  end

  def collect_file_examples(file_path)
    content = File.read(file_path)
    relative_path = file_path.sub(@root_path, '').sub(%r{^/}, '')

    # Collect good patterns
    content.scan(/log_exception_to_sentry\((.*?)\)/m).each do |match|
      @examples[:good_sentry] << {
        file: relative_path,
        code: match[0].strip
      } if @examples[:good_sentry].length < 5
    end

    # Collect error handling patterns
    content.scan(/rescue\s+=>\s+(\w+)\n(.*?)end/m).each do |match|
      @examples[:error_handling] << {
        file: relative_path,
        exception_var: match[0],
        body: match[1].strip
      } if @examples[:error_handling].length < 5
    end
  end

  def create_markdown_guide
    timestamp = Time.now.strftime('%Y-%m-%d')
    guide = <<~'MARKDOWN'
      # Logging Standardization Guide for vets-api

      **Version:** 1.0
      **Last Updated:** TIMESTAMP_PLACEHOLDER
      **Status:** Draft for Review

      ## Table of Contents

      1. [Overview](#overview)
      2. [Logging Methods](#logging-methods)
      3. [Standard Patterns](#standard-patterns)
      4. [Anti-Patterns](#anti-patterns)
      5. [Migration Guide](#migration-guide)
      6. [Testing Logging](#testing-logging)

      ---

      ## Overview

      This guide establishes standard logging practices for the vets-api platform to ensure:
      - **Consistency** across the codebase
      - **Observability** for debugging and monitoring
      - **Performance** by avoiding duplicate logging
      - **Cost efficiency** by not over-logging to multiple services

      ### Current State Analysis

      Our analysis revealed:
      - Multiple logging methods in use (Rails.logger, Sentry, custom helpers)
      - Duplicate logging (same exception logged to both Sentry and Rails)
      - Inconsistent error handling patterns
      - Some uses of `puts`/`print` in production code

      ---

      ## Logging Methods

      ### Approved Methods

      #### 1. Exception Logging

      **Use:** `log_exception_to_sentry(exception, extra_context = {}, tags_context = {}, level = 'error')`

      **When to use:**
      - For all exceptions that should be tracked and monitored
      - When you need to add context for debugging
      - When exceptions require team notification

      **Behavior:**
      - Sends to Sentry if configured
      - Falls back to Rails.logger if Sentry unavailable
      - Automatically includes exception cause chain

      ```ruby
      # ✅ GOOD
      begin
        dangerous_operation
      rescue => e
        log_exception_to_sentry(
          e,
          { user_id: current_user.id, operation: 'dangerous_operation' },
          { component: 'payment_processor' }
        )
      end
      ```

      #### 2. Message Logging

      **Use:** `log_message_to_sentry(message, context = {}, tags = {}, level = 'info')`

      **When to use:**
      - For important business events
      - For warnings that need tracking
      - For audit trails

      ```ruby
      # ✅ GOOD
      log_message_to_sentry(
        'Payment processing started',
        { amount: payment.amount, user_id: user.id },
        { service: 'payment' },
        'info'
      )
      ```

      #### 3. General Application Logging

      **Use:** `Rails.logger.[debug|info|warn|error|fatal](message)`

      **When to use:**
      - For general application flow logging
      - For debugging information
      - For non-critical warnings
      - When you DON'T need Sentry notification

      ```ruby
      # ✅ GOOD - General flow
      Rails.logger.info("User #{user.id} logged in from #{request.ip}")

      # ✅ GOOD - Debug info (won't spam Sentry)
      Rails.logger.debug("Cache hit for key: #{cache_key}")

      # ✅ GOOD - Non-critical warning
      Rails.logger.warn("Slow query detected: #{query_time}ms")
      ```

      #### 4. Metrics and Monitoring

      **Use:** `StatsD.increment(stat, tags: [])`

      **When to use:**
      - For performance metrics
      - For counting events
      - For monitoring KPIs

      ```ruby
      # ✅ GOOD
      StatsD.increment('api.requests', tags: ['endpoint:claims', 'status:success'])
      ```

      ---

      ## Standard Patterns

      ### Pattern 1: Exception Handling in Controllers

      ```ruby
      # ✅ GOOD
      def create
        service = ClaimService.new(current_user)
        result = service.submit_claim(params)
        render json: result, status: :created
      rescue ClaimService::ValidationError => e
        log_exception_to_sentry(e, { params: params.to_h }, { controller: 'claims' })
        render json: { error: e.message }, status: :unprocessable_entity
      rescue => e
        log_exception_to_sentry(e, { params: params.to_h }, { controller: 'claims' })
        render json: { error: 'Internal server error' }, status: :internal_server_error
      end
      ```

      ### Pattern 2: Exception Handling in Background Jobs

      ```ruby
      # ✅ GOOD
      class ProcessClaimJob < ApplicationJob
        def perform(claim_id)
          claim = Claim.find(claim_id)
          process_claim(claim)
          Rails.logger.info("Successfully processed claim #{claim_id}")
        rescue ActiveRecord::RecordNotFound => e
          log_exception_to_sentry(e, { claim_id: claim_id }, { job: 'process_claim' })
          # Don't retry - record doesn't exist
        rescue => e
          log_exception_to_sentry(e, { claim_id: claim_id }, { job: 'process_claim' })
          raise # Allow Sidekiq to retry
        end
      end
      ```

      ### Pattern 3: External API Calls

      ```ruby
      # ✅ GOOD
      def fetch_veteran_info(icn)
        Rails.logger.info("Fetching veteran info for ICN: #{icn}")

        response = va_profile_client.get_veteran(icn)
        StatsD.increment('va_profile.requests', tags: ['status:success'])

        response.body
      rescue Faraday::TimeoutError => e
        StatsD.increment('va_profile.requests', tags: ['status:timeout'])
        log_exception_to_sentry(
          e,
          { icn: icn, timeout: va_profile_client.timeout },
          { service: 'va_profile' },
          'warn'
        )
        nil
      rescue => e
        StatsD.increment('va_profile.requests', tags: ['status:error'])
        log_exception_to_sentry(e, { icn: icn }, { service: 'va_profile' })
        raise
      end
      ```

      ### Pattern 4: Graceful Degradation

      ```ruby
      # ✅ GOOD
      def initialize_va_profile_data
        fetch_va_profile_data
      rescue => e
        log_exception_to_sentry(e, {}, { prefill: :va_profile })
        Rails.logger.warn("VA Profile unavailable, using empty data")
        {}
      end
      ```

      ---

      ## Anti-Patterns

      ### ❌ Anti-Pattern 1: Duplicate Logging

      **Problem:** Logging the same exception to multiple destinations

      ```ruby
      # ❌ BAD
      rescue => e
        log_exception_to_sentry(e)
        log_exception_to_rails(e)  # DUPLICATE - Sentry already logs to Rails
      end

      # ✅ GOOD
      rescue => e
        log_exception_to_sentry(e)  # This handles both Sentry and Rails
      end
      ```

      **Why it's bad:**
      - Creates duplicate log entries in DataDog
      - Wastes logging budget
      - Makes log analysis harder

      ### ❌ Anti-Pattern 2: Using puts/print in Production Code

      ```ruby
      # ❌ BAD
      def process_payment
        puts "Processing payment for user #{user.id}"  # Lost in production!
        # ...
      end

      # ✅ GOOD
      def process_payment
        Rails.logger.info("Processing payment for user #{user.id}")
        # ...
      end
      ```

      ### ❌ Anti-Pattern 3: Logging Without Context

      ```ruby
      # ❌ BAD
      rescue => e
        log_exception_to_sentry(e)  # What was I doing when this failed?
      end

      # ✅ GOOD
      rescue => e
        log_exception_to_sentry(
          e,
          { user_id: user.id, claim_id: claim.id, step: 'validation' },
          { service: 'claims_processor' }
        )
      end
      ```

      ### ❌ Anti-Pattern 4: Over-logging to Sentry

      ```ruby
      # ❌ BAD - This will spam Sentry
      users.each do |user|
        if user.email.blank?
          log_exception_to_sentry(
            StandardError.new("User missing email"),
            { user_id: user.id }
          )
        end
      end

      # ✅ GOOD - Use Rails logger for non-critical issues
      invalid_users = users.select { |u| u.email.blank? }
      if invalid_users.any?
        Rails.logger.warn("Found #{invalid_users.length} users with missing emails")
        log_message_to_sentry(
          "Batch contains users with missing emails",
          { count: invalid_users.length },
          { service: 'user_validator' },
          'warn'
        )
      end
      ```

      ### ❌ Anti-Pattern 5: Swallowing Exceptions Silently

      ```ruby
      # ❌ BAD
      begin
        risky_operation
      rescue => e
        # Silent failure - nobody knows this happened!
      end

      # ✅ GOOD - At minimum, log it
      begin
        risky_operation
      rescue => e
        log_exception_to_sentry(e, { operation: 'risky_operation' })
        # Then decide: re-raise, return nil, or continue
      end
      ```

      ---

      ## Migration Guide

      ### Step 1: Identify Patterns to Fix

      Run the analysis script:
      ```bash
      ruby analyze_logging_patterns.rb /path/to/vets-api
      ```

      ### Step 2: Test Changes

      Run the fix script in dry-run mode:
      ```bash
      ruby fix_logging_patterns.rb /path/to/vets-api --dry-run
      ```

      ### Step 3: Apply Changes

      ```bash
      ruby fix_logging_patterns.rb /path/to/vets-api
      ```

      ### Step 4: Manual Review

      Some patterns require manual review:
      - Direct `Sentry.capture_exception` calls
      - Complex error handling logic
      - Logging in tight loops

      ### Step 5: Update Tests

      Update specs to match new logging patterns (see Testing section below).

      ---

      ## Testing Logging

      ### Testing Exception Logging

      ```ruby
      # ✅ GOOD
      it 'logs exception when service fails' do
        allow(service).to receive(:call).and_raise(StandardError.new('boom'))

        expect(controller).to receive(:log_exception_to_sentry).with(
          instance_of(StandardError),
          hash_including(user_id: user.id),
          hash_including(controller: 'claims')
        )

        post :create, params: { claim: claim_params }
      end
      ```

      ### Testing Message Logging

      ```ruby
      # ✅ GOOD
      it 'logs successful processing' do
        expect(Rails.logger).to receive(:info).with(/Successfully processed claim/)

        subject.process_claim(claim)
      end
      ```

      ### Don't Over-Test Logging

      ```ruby
      # ❌ BAD - Testing implementation details
      it 'logs exception' do
        expect(Sentry).to receive(:capture_exception)
        expect(Rails.logger).to receive(:error)
        # ...
      end

      # ✅ GOOD - Test the behavior, not the logging
      it 'handles service failures gracefully' do
        allow(service).to receive(:call).and_raise(StandardError)

        expect { subject.perform }.not_to raise_error
        expect(subject.result).to be_nil
      end
      ```

      ---

      ## Decision Matrix

      | Situation | Use | Don't Use |
      |-----------|-----|-----------|
      | Exception needs tracking | `log_exception_to_sentry` | `log_exception_to_rails` |
      | Important business event | `log_message_to_sentry` | `Rails.logger` |
      | Debug/flow information | `Rails.logger.debug/info` | `log_message_to_sentry` |
      | Performance metrics | `StatsD.increment` | `Rails.logger` |
      | Non-critical warning | `Rails.logger.warn` | `log_message_to_sentry` |
      | Expected validation errors | `Rails.logger.info` | `log_exception_to_sentry` |

      ---

      ## FAQ

      **Q: Should I log exceptions from external API failures?**
      A: Yes, use `log_exception_to_sentry` with appropriate context and consider using 'warn' level for timeouts.

      **Q: What about logging in tight loops?**
      A: Avoid logging in loops. Instead, log summary statistics after the loop completes.

      **Q: How much context should I include?**
      A: Include enough to debug the issue without the original request. User IDs, resource IDs, and the operation being performed are usually sufficient.

      **Q: Should I log PII?**
      A: No. Never log SSNs, full addresses, or other sensitive data. Use IDs and anonymized data only.

      **Q: What log level should I use?**
      A:
      - `debug`: Detailed diagnostic info
      - `info`: General application flow
      - `warn`: Potentially harmful situations
      - `error`: Error events that still allow the app to continue
      - `fatal`: Severe errors causing app termination

      ---

      ## Enforcement

      ### RuboCop Rules (See .rubocop_logging.yml)

      We've added custom RuboCop rules to enforce these standards:
      - Detect duplicate logging patterns
      - Flag uses of `puts`/`print` in non-spec files
      - Encourage proper exception handling

      ### Code Review Checklist

      - [ ] No duplicate logging (both Sentry and Rails)
      - [ ] Exceptions include meaningful context
      - [ ] No `puts`/`print` in production code
      - [ ] Appropriate log levels used
      - [ ] No PII in logs
      - [ ] Loops don't log on every iteration

      ---

      ## Resources

      - [Sentry Ruby Documentation](https://docs.sentry.io/platforms/ruby/)
      - [Rails Logging Guide](https://guides.rubyonrails.org/debugging_rails_applications.html#the-logger)
      - [StatsD Documentation](https://github.com/DataDog/dogstatsd-ruby)

      ---

      ## Changelog

      - **2024-12-12**: Initial version

    MARKDOWN

    guide = guide.gsub('TIMESTAMP_PLACEHOLDER', timestamp)

    File.write('LOGGING_STANDARDS.md', guide)
    puts "  ✅ Created: LOGGING_STANDARDS.md"
  end

  def create_rubocop_config
    config = <<~'YAML'
      # Logging Standards Enforcement
      # Add this to your .rubocop.yml:
      # require:
      #   - ./config/rubocop_logging.rb

      # Detect duplicate logging patterns
      Lint/DuplicateLogging:
        Description: 'Avoid logging the same exception to multiple destinations'
        Enabled: true
        Exclude:
          - 'spec/**/*'

      # Detect puts/print in production code
      Lint/PrintInProductionCode:
        Description: 'Use Rails.logger instead of puts/print in production code'
        Enabled: true
        Exclude:
          - 'spec/**/*'
          - 'db/migrate/**/*'
          - 'lib/tasks/**/*'
          - 'script/**/*'

      # Encourage exception context
      Lint/ExceptionWithoutContext:
        Description: 'Exceptions logged to Sentry should include context'
        Enabled: true
        Exclude:
          - 'spec/**/*'

      Style/LoggingConsistency:
        Description: 'Use standard logging helpers consistently'
        Enabled: true
        Exclude:
          - 'spec/**/*'
    YAML

    File.write('.rubocop_logging.yml', config)
    puts "  ✅ Created: .rubocop_logging.yml"
  end
end

# Main execution
if ARGV.empty?
  puts "Usage: ruby generate_logging_guide.rb /path/to/vets-api"
  exit 1
end

generator = LoggingGuideGenerator.new(ARGV[0])
generator.generate