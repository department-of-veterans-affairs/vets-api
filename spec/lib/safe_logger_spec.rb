# frozen_string_literal: true

require 'rails_helper'
require 'safe_logger'

RSpec.describe SafeLogger do
  describe 'log level methods' do
    %i[debug info warn error fatal].each do |level|
      describe ".#{level}" do
        it 'delegates to Rails.logger' do
          expect(Rails.logger).to receive(level).with('test message', nil)
          SafeLogger.public_send(level, 'test message')
        end

        it 'accepts a payload hash' do
          expect(Rails.logger).to receive(level).with('test message', hash_including(:id))
          SafeLogger.public_send(level, 'test message', { id: 123 })
        end

        it 'accepts an allowlist parameter' do
          expect do
            SafeLogger.public_send(level, 'test message', { email: 'test@example.com' }, allowlist: [:email])
          end.not_to raise_error
        end
      end
    end
  end

  describe 'payload filtering' do
    it 'filters sensitive data by default' do
      expect(Rails.logger).to receive(:info) do |message, payload|
        expect(message).to eq('test')
        expect(payload[:ssn]).to eq('[FILTERED]')
        expect(payload[:email]).to eq('[FILTERED]')
      end

      SafeLogger.info('test', { ssn: '123-45-6789', email: 'user@example.com' })
    end

    it 'allows specified keys when allowlist is provided' do
      expect(Rails.logger).to receive(:info) do |_message, payload|
        expect(payload[:ssn]).to eq('[FILTERED]')
        expect(payload[:email]).to eq('user@example.com')
      end

      SafeLogger.info('test', { ssn: '123-45-6789', email: 'user@example.com' }, allowlist: [:email])
    end

    it 'allows multiple keys in allowlist' do
      expect(Rails.logger).to receive(:info) do |_message, payload|
        expect(payload[:ssn]).to eq('[FILTERED]')
        expect(payload[:email]).to eq('user@example.com')
        expect(payload[:phone]).to eq('555-1234')
      end

      SafeLogger.info('test', { ssn: '123-45-6789', email: 'user@example.com', phone: '555-1234' },
                      allowlist: %i[email phone])
    end

    it 'accepts string keys in allowlist' do
      expect(Rails.logger).to receive(:info) do |_message, payload|
        expect(payload[:email]).to eq('user@example.com')
      end

      SafeLogger.info('test', { ssn: '123-45-6789', email: 'user@example.com' }, allowlist: ['email'])
    end

    it 'returns nil payload unchanged' do
      expect(Rails.logger).to receive(:info).with('test', nil)
      SafeLogger.info('test', nil)
    end

    it 'respects global ALLOWLIST for keys' do
      expect(Rails.logger).to receive(:info) do |_message, payload|
        expect(payload[:id]).to eq(123)
        expect(payload[:controller]).to eq('test')
        expect(payload[:ssn]).to eq('[FILTERED]')
      end

      SafeLogger.info('test', { id: 123, ssn: '123-45-6789', controller: 'test' })
    end
  end

  describe 'nested data structures' do
    it 'filters nested hashes' do
      expect(Rails.logger).to receive(:info) do |_message, payload|
        expect(payload[:user][:email]).to eq('user@example.com')
        expect(payload[:user][:ssn]).to eq('[FILTERED]')
      end

      SafeLogger.info('test', { user: { ssn: '123-45-6789', email: 'user@example.com' } }, allowlist: [:email])
    end

    it 'filters arrays of hashes' do
      expect(Rails.logger).to receive(:info) do |_message, payload|
        expect(payload[:users][0][:email]).to eq('user1@example.com')
        expect(payload[:users][0][:ssn]).to eq('[FILTERED]')
        expect(payload[:users][1][:email]).to eq('user2@example.com')
        expect(payload[:users][1][:ssn]).to eq('[FILTERED]')
      end

      SafeLogger.info('test', {
                        users: [
                          { ssn: '123-45-6789', email: 'user1@example.com' },
                          { ssn: '987-65-4321', email: 'user2@example.com' }
                        ]
                      }, allowlist: [:email])
    end
  end

  describe 'message string filtering' do
    it 'filters object inspect strings with attr: value pattern' do
      expect(Rails.logger).to receive(:info) do |message, _payload|
        expect(message).to include('id: 123')
        expect(message).to include('ssn: [FILTERED]')
        expect(message).to include('email: "user@example.com"')
      end

      SafeLogger.info('#<User id: 123, ssn: "123-45-6789", email: "user@example.com">', nil, allowlist: [:email])
    end

    it 'filters object inspect strings with @attr=value pattern' do
      expect(Rails.logger).to receive(:info) do |message, _payload|
        expect(message).to include('@ssn=[FILTERED]')
        expect(message).to include('@email="user@example.com"')
      end

      SafeLogger.info('#<User @ssn="123-45-6789", @email="user@example.com">', nil, allowlist: [:email])
    end

    it 'does not filter regular strings' do
      expect(Rails.logger).to receive(:info).with('Regular log message', nil)
      SafeLogger.info('Regular log message')
    end
  end

  describe 'data mutation protection' do
    it 'does not mutate the original payload hash' do
      original_payload = { ssn: '123-45-6789', email: 'user@example.com' }
      payload_copy = original_payload.dup

      allow(Rails.logger).to receive(:info)
      SafeLogger.info('test', original_payload, allowlist: [:email])

      expect(original_payload).to eq(payload_copy)
    end

    it 'does not mutate nested data structures' do
      original_payload = { user: { ssn: '123-45-6789', email: 'user@example.com' } }
      payload_copy = original_payload.deep_dup

      allow(Rails.logger).to receive(:info)
      SafeLogger.info('test', original_payload, allowlist: [:email])

      expect(original_payload).to eq(payload_copy)
    end
  end

  describe 'error handling' do
    it 'logs original data if filtering fails' do
      allow(ParameterFilterHelper).to receive(:filter_params).and_raise(StandardError, 'filter error')

      expect(Rails.logger).to receive(:warn).with('SafeLogger filtering error: filter error')
      expect(Rails.logger).to receive(:info).with('test', { data: 'value' })

      SafeLogger.info('test', { data: 'value' })
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
      expect { SafeLogger.info('test', { ssn: '123-45-6789' }, allowlist: [:email]) }.not_to raise_error
    end
  end
end
