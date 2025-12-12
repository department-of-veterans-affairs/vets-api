# frozen_string_literal: true

require 'rails_helper'
require 'allowlist_log_filtering'

RSpec.describe AllowlistLogFiltering do
  # Create a test class that includes the module for testing the filtering methods
  let(:filter_tester) do
    Class.new do
      include AllowlistLogFiltering

      # Make private methods accessible for testing
      public :filter_payload, :filter_message_string, :filter_with_allowlist
    end.new
  end

  describe 'log level methods with log_allowlist parameter' do
    let(:extended_logger) do
      Rails.logger.extend(AllowlistLogFiltering)
      Rails.logger
    end

    it 'supports log_allowlist parameter on info' do
      expect { extended_logger.info('test message', log_allowlist: [:email]) }.not_to raise_error
    end

    it 'supports log_allowlist parameter on debug' do
      expect { extended_logger.debug('test message', log_allowlist: [:email]) }.not_to raise_error
    end

    it 'supports log_allowlist parameter on warn' do
      expect { extended_logger.warn('test message', log_allowlist: [:email]) }.not_to raise_error
    end

    it 'supports log_allowlist parameter on error' do
      expect { extended_logger.error('test message', log_allowlist: [:email]) }.not_to raise_error
    end

    it 'supports log_allowlist parameter on fatal' do
      expect { extended_logger.fatal('test message', log_allowlist: [:email]) }.not_to raise_error
    end
  end

  describe '#filter_payload' do
    it 'filters sensitive data by default when no allowlist provided' do
      payload = { ssn: '123-45-6789', email: 'user@example.com' }
      result = filter_tester.filter_payload(payload, [])

      expect(result[:ssn]).to eq('[FILTERED]')
      expect(result[:email]).to eq('[FILTERED]')
    end

    it 'allows specified keys when allowlist is provided' do
      payload = { ssn: '123-45-6789', email: 'user@example.com' }
      result = filter_tester.filter_payload(payload, ['email'])

      expect(result[:ssn]).to eq('[FILTERED]')
      expect(result[:email]).to eq('user@example.com')
    end

    it 'allows multiple keys in allowlist' do
      payload = { ssn: '123-45-6789', email: 'user@example.com', phone: '555-1234' }
      result = filter_tester.filter_payload(payload, %w[email phone])

      expect(result[:ssn]).to eq('[FILTERED]')
      expect(result[:email]).to eq('user@example.com')
      expect(result[:phone]).to eq('555-1234')
    end

    it 'accepts string keys in allowlist' do
      payload = { ssn: '123-45-6789', email: 'user@example.com' }
      result = filter_tester.filter_payload(payload, ['email'])

      expect(result[:email]).to eq('user@example.com')
      expect(result[:ssn]).to eq('[FILTERED]')
    end

    it 'accepts symbol keys in allowlist converted to strings' do
      payload = { 'ssn' => '123-45-6789', 'email' => 'user@example.com' }
      result = filter_tester.filter_payload(payload, ['email'])

      expect(result['email']).to eq('user@example.com')
      expect(result['ssn']).to eq('[FILTERED]')
    end

    it 'returns nil for nil payloads' do
      result = filter_tester.filter_payload(nil, [])
      expect(result).to be_nil
    end

    it 'returns non-hash payloads unchanged' do
      result = filter_tester.filter_payload('string', [])
      expect(result).to eq('string')
    end
  end

  describe 'nested data structures' do
    it 'filters nested hashes respecting allowlist' do
      payload = {
        user: {
          ssn: '123-45-6789',
          email: 'user@example.com',
          name: 'John Doe'
        }
      }
      result = filter_tester.filter_payload(payload, ['email'])

      expect(result[:user][:email]).to eq('user@example.com')
      expect(result[:user][:ssn]).to eq('[FILTERED]')
      expect(result[:user][:name]).to eq('[FILTERED]')
    end

    it 'filters arrays of hashes respecting allowlist' do
      payload = {
        users: [
          { ssn: '123-45-6789', email: 'user1@example.com' },
          { ssn: '987-65-4321', email: 'user2@example.com' }
        ]
      }
      result = filter_tester.filter_payload(payload, ['email'])

      expect(result[:users][0][:email]).to eq('user1@example.com')
      expect(result[:users][0][:ssn]).to eq('[FILTERED]')
      expect(result[:users][1][:email]).to eq('user2@example.com')
      expect(result[:users][1][:ssn]).to eq('[FILTERED]')
    end

    it 'handles deeply nested structures' do
      payload = {
        level1: {
          level2: {
            ssn: '123-45-6789',
            email: 'nested@example.com'
          }
        }
      }
      result = filter_tester.filter_payload(payload, ['email'])

      expect(result[:level1][:level2][:email]).to eq('nested@example.com')
      expect(result[:level1][:level2][:ssn]).to eq('[FILTERED]')
    end

    it 'filters nested sensitive data even when parent key is allowlisted' do
      payload = {
        user: {
          name: 'John Doe',
          ssn: '123-45-6789',
          email: 'user@example.com'
        }
      }
      result = filter_tester.filter_payload(payload, ['user'])

      # Even though 'user' is allowlisted, nested sensitive fields should still be filtered
      expect(result[:user][:ssn]).to eq('[FILTERED]')
      expect(result[:user][:name]).to eq('[FILTERED]')
      expect(result[:user][:email]).to eq('[FILTERED]')
    end
  end

  describe 'interaction with global ALLOWLIST' do
    it 'respects global ALLOWLIST for keys not in per-call allowlist' do
      payload = { id: 123, ssn: '123-45-6789', controller: 'test' }
      result = filter_tester.filter_payload(payload, [])

      expect(result[:id]).to eq(123) # id is in global ALLOWLIST
      expect(result[:controller]).to eq('test') # controller is in global ALLOWLIST
      expect(result[:ssn]).to eq('[FILTERED]')
    end

    it 'per-call allowlist allows sensitive keys' do
      payload = { ssn: '123-45-6789', email: 'user@example.com' }
      result = filter_tester.filter_payload(payload, ['ssn'])

      expect(result[:ssn]).to eq('123-45-6789')
      expect(result[:email]).to eq('[FILTERED]')
    end

    it 'combines global ALLOWLIST with per-call allowlist' do
      payload = { id: 123, ssn: '123-45-6789', email: 'user@example.com' }
      result = filter_tester.filter_payload(payload, ['email'])

      expect(result[:id]).to eq(123)
      expect(result[:email]).to eq('user@example.com')
      expect(result[:ssn]).to eq('[FILTERED]')
    end
  end

  describe 'edge cases' do
    it 'works with empty allowlist' do
      payload = { ssn: '123-45-6789', email: 'user@example.com' }
      result = filter_tester.filter_payload(payload, [])

      expect(result[:ssn]).to eq('[FILTERED]')
      expect(result[:email]).to eq('[FILTERED]')
    end

    it 'handles allowlist keys that do not exist in data' do
      payload = { ssn: '123-45-6789' }
      result = filter_tester.filter_payload(payload, %w[email phone])

      expect(result[:ssn]).to eq('[FILTERED]')
    end
  end

  describe '#filter_message_string' do
    it 'filters object inspect strings with @attr=value pattern' do
      inspect_string = '#<User @ssn="123-45-6789", @email="user@example.com">'
      result = filter_tester.filter_message_string(inspect_string, ['email'])

      expect(result).to include('@ssn=[FILTERED]')
      expect(result).to include('@email="user@example.com"')
    end

    it 'filters object inspect strings with attr: value pattern' do
      inspect_string = '#<User id: 123, ssn: "123-45-6789", email: "user@example.com">'
      result = filter_tester.filter_message_string(inspect_string, ['email'])

      expect(result).to include('id: 123') # id is in global ALLOWLIST
      expect(result).to include('ssn: [FILTERED]')
      expect(result).to include('email: "user@example.com"')
    end

    it 'respects global ALLOWLIST for object inspect' do
      inspect_string = '#<Request id: 123, status: "active", ssn: "123-45-6789">'
      result = filter_tester.filter_message_string(inspect_string, [])

      expect(result).to include('id: 123')
      expect(result).to include('status: "active"')
      expect(result).to include('ssn: [FILTERED]')
    end

    it 'does not filter regular strings that are not object inspect' do
      message = 'Regular log message without object pattern'
      result = filter_tester.filter_message_string(message, [])

      expect(result).to eq(message)
    end

    it 'returns non-string messages unchanged' do
      result = filter_tester.filter_message_string(nil, [])
      expect(result).to be_nil
    end

    it 'filters nested object inspect strings' do
      inspect_string = '#<User id: 1, profile: #<Profile ssn: "123-45-6789", email: "user@example.com">>'
      result = filter_tester.filter_message_string(inspect_string, ['email'])

      expect(result).to include('ssn: [FILTERED]')
      expect(result).to include('email: "user@example.com"')
    end
  end

  describe 'data mutation' do
    it 'does not mutate the original payload hash' do
      original_payload = { ssn: '123-45-6789', email: 'user@example.com' }
      payload_copy = original_payload.dup

      filter_tester.filter_payload(original_payload, ['email'])

      expect(original_payload).to eq(payload_copy)
    end

    it 'does not mutate nested data structures' do
      original_payload = {
        user: { ssn: '123-45-6789', email: 'user@example.com' }
      }
      payload_copy = original_payload.deep_dup

      filter_tester.filter_payload(original_payload, ['email'])

      expect(original_payload).to eq(payload_copy)
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
      payload = { ssn: '123-45-6789', email: 'user@example.com' }
      expect { filter_tester.filter_payload(payload, ['email']) }.not_to raise_error
    end

    it 'falls back to ParameterFilterHelper when no global filter exists' do
      payload = { ssn: '123-45-6789', email: 'user@example.com' }
      result = filter_tester.filter_payload(payload, ['email'])

      # When filter_parameters is empty, ParameterFilterHelper.filter_params
      # also has no filters configured, so data passes through unfiltered.
      expect(result[:ssn]).to eq('123-45-6789')
      expect(result[:email]).to eq('user@example.com')
    end
  end
end
