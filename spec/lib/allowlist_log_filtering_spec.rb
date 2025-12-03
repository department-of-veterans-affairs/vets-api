# frozen_string_literal: true

require 'rails_helper'
require 'allowlist_log_filtering'

RSpec.describe AllowlistLogFiltering do
  let(:test_logger) do
    logger = Logger.new(StringIO.new)
    logger.extend(AllowlistLogFiltering)
    logger
  end

  let(:log_output) { StringIO.new }
  let(:logger_with_output) do
    logger = Logger.new(log_output)
    logger.extend(AllowlistLogFiltering)
    logger
  end

  describe 'log level methods with log_allowlist parameter' do
    it 'supports log_allowlist parameter on info' do
      expect { test_logger.info('test message', log_allowlist: [:email]) }.not_to raise_error
    end

    it 'supports log_allowlist parameter on debug' do
      expect { test_logger.debug('test message', log_allowlist: [:email]) }.not_to raise_error
    end

    it 'supports log_allowlist parameter on warn' do
      expect { test_logger.warn('test message', log_allowlist: [:email]) }.not_to raise_error
    end

    it 'supports log_allowlist parameter on error' do
      expect { test_logger.error('test message', log_allowlist: [:email]) }.not_to raise_error
    end

    it 'supports log_allowlist parameter on fatal' do
      expect { test_logger.fatal('test message', log_allowlist: [:email]) }.not_to raise_error
    end
  end

  describe 'filtering with per-call allowlist' do
    it 'filters sensitive data by default' do
      data = { ssn: '123-45-6789', email: 'user@example.com' }
      logger_with_output.info(data)

      output = log_output.string
      expect(output).to include('[FILTERED]')
      expect(output).not_to include('123-45-6789')
      expect(output).not_to include('user@example.com')
    end

    it 'allows specified keys when log_allowlist is provided' do
      data = { ssn: '123-45-6789', email: 'user@example.com' }
      logger_with_output.info(data, log_allowlist: [:email])

      output = log_output.string
      expect(output).to include('user@example.com') # email is allowed
      expect(output).not_to include('123-45-6789')  # ssn is still filtered
    end

    it 'allows multiple keys in log_allowlist' do
      data = { ssn: '123-45-6789', email: 'user@example.com', phone: '555-1234' }
      logger_with_output.info(data, log_allowlist: [:email, :phone])

      output = log_output.string
      expect(output).to include('user@example.com')
      expect(output).to include('555-1234')
      expect(output).not_to include('123-45-6789')
    end

    it 'accepts string keys in log_allowlist' do
      data = { ssn: '123-45-6789', email: 'user@example.com' }
      logger_with_output.info(data, log_allowlist: ['email'])

      output = log_output.string
      expect(output).to include('user@example.com')
      expect(output).not_to include('123-45-6789')
    end

    it 'accepts symbol keys in log_allowlist' do
      data = { 'ssn' => '123-45-6789', 'email' => 'user@example.com' }
      logger_with_output.info(data, log_allowlist: [:email])

      output = log_output.string
      expect(output).to include('user@example.com')
      expect(output).not_to include('123-45-6789')
    end
  end

  describe 'nested data structures' do
    it 'filters nested hashes respecting allowlist' do
      data = {
        user: {
          ssn: '123-45-6789',
          email: 'user@example.com',
          name: 'John Doe'
        }
      }
      logger_with_output.info(data, log_allowlist: [:email])

      output = log_output.string
      expect(output).to include('user@example.com')
      expect(output).not_to include('123-45-6789')
      expect(output).not_to include('John Doe')
    end

    it 'filters arrays of hashes respecting allowlist' do
      data = {
        users: [
          { ssn: '123-45-6789', email: 'user1@example.com' },
          { ssn: '987-65-4321', email: 'user2@example.com' }
        ]
      }
      logger_with_output.info(data, log_allowlist: [:email])

      output = log_output.string
      expect(output).to include('user1@example.com')
      expect(output).to include('user2@example.com')
      expect(output).not_to include('123-45-6789')
      expect(output).not_to include('987-65-4321')
    end

    it 'handles deeply nested structures' do
      data = {
        level1: {
          level2: {
            ssn: '123-45-6789',
            email: 'nested@example.com'
          }
        }
      }
      logger_with_output.info(data, log_allowlist: [:email])

      output = log_output.string
      expect(output).to include('nested@example.com')
      expect(output).not_to include('123-45-6789')
    end
  end

  describe 'interaction with global ALLOWLIST' do
    it 'respects global ALLOWLIST for keys not in per-call allowlist' do
      data = { id: 123, ssn: '123-45-6789', controller: 'test' }
      logger_with_output.info(data, log_allowlist: [])

      output = log_output.string
      expect(output).to include('123')       # id is in global ALLOWLIST
      expect(output).to include('test')      # controller is in global ALLOWLIST
      expect(output).not_to include('123-45-6789') # ssn is not in any allowlist
    end

    it 'per-call allowlist overrides global filtering' do
      # Even if a key is not in the global ALLOWLIST, per-call allowlist should allow it
      data = { ssn: '123-45-6789', email: 'user@example.com' }
      logger_with_output.info(data, log_allowlist: [:ssn])

      output = log_output.string
      expect(output).to include('123-45-6789') # ssn is in per-call allowlist
      expect(output).not_to include('user@example.com') # email is filtered
    end

    it 'combines global ALLOWLIST with per-call allowlist' do
      data = { id: 123, ssn: '123-45-6789', email: 'user@example.com' }
      logger_with_output.info(data, log_allowlist: [:email])

      output = log_output.string
      expect(output).to include('123')              # id from global ALLOWLIST
      expect(output).to include('user@example.com') # email from per-call allowlist
      expect(output).not_to include('123-45-6789')  # ssn filtered
    end
  end

  describe 'edge cases' do
    it 'works with empty log_allowlist' do
      data = { ssn: '123-45-6789', email: 'user@example.com' }
      logger_with_output.info(data, log_allowlist: [])

      output = log_output.string
      expect(output).to include('[FILTERED]')
      expect(output).not_to include('123-45-6789')
      expect(output).not_to include('user@example.com')
    end

    it 'works without log_allowlist parameter' do
      data = { ssn: '123-45-6789', email: 'user@example.com' }
      logger_with_output.info(data)

      output = log_output.string
      expect(output).to include('[FILTERED]')
      expect(output).not_to include('123-45-6789')
      expect(output).not_to include('user@example.com')
    end

    it 'works with string messages' do
      logger_with_output.info('Simple string message', log_allowlist: [:email])
      output = log_output.string
      expect(output).to include('Simple string message')
    end

    it 'works with nil message' do
      expect { logger_with_output.info(nil, log_allowlist: [:email]) }.not_to raise_error
    end

    it 'handles allowlist keys that do not exist in data' do
      data = { ssn: '123-45-6789' }
      logger_with_output.info(data, log_allowlist: [:email, :phone])

      output = log_output.string
      expect(output).not_to include('123-45-6789')
    end
  end

  describe 'data mutation' do
    it 'does not mutate the original data hash' do
      original_data = { ssn: '123-45-6789', email: 'user@example.com' }
      data_copy = original_data.dup

      logger_with_output.info(original_data, log_allowlist: [:email])

      expect(original_data).to eq(data_copy)
    end

    it 'does not mutate nested data structures' do
      original_data = {
        user: { ssn: '123-45-6789', email: 'user@example.com' }
      }
      data_copy = original_data.deep_dup

      logger_with_output.info(original_data, log_allowlist: [:email])

      expect(original_data).to eq(data_copy)
    end
  end

  context 'when Rails.application.config.filter_parameters is empty' do
    before do
      @original_filters = Rails.application.config.filter_parameters.dup
      Rails.application.config.filter_parameters = []
    end

    after do
      Rails.application.config.filter_parameters = @original_filters
    end

    it 'does not error when filter_parameters is empty' do
      data = { ssn: '123-45-6789', email: 'user@example.com' }
      expect { logger_with_output.info(data, log_allowlist: [:email]) }.not_to raise_error
    end

    it 'returns unfiltered data when no global filter exists' do
      data = { ssn: '123-45-6789', email: 'user@example.com' }
      logger_with_output.info(data, log_allowlist: [:email])

      output = log_output.string
      # Without global filter, data passes through
      expect(output).to include('123-45-6789')
      expect(output).to include('user@example.com')
    end
  end
end
