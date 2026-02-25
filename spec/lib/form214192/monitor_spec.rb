# frozen_string_literal: true

require 'rails_helper'
require 'form214192/monitor'

RSpec.describe Form214192::Monitor do
  subject(:monitor) { described_class.new }

  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:form_id) { described_class::FORM_ID }

  describe 'BaseMonitor abstract methods' do
    it 'implements required methods' do
      expect(monitor.claim_stats_key).to eq('api.form214192')
      expect(monitor.name).to eq('form214192')
      expect(monitor.form_id).to eq('21-4192')
    end

    it 'has required tags' do
      expect(monitor.tags).to eq(['form_id:21-4192'])
    end

    it 'responds to BaseMonitor lifecycle methods' do
      expect(monitor).to respond_to(:track_create_attempt)
      expect(monitor).to respond_to(:track_create_success)
      expect(monitor).to respond_to(:track_create_error)
      expect(monitor).to respond_to(:track_create_validation_error)
      expect(monitor).to respond_to(:track_submission_begun)
      expect(monitor).to respond_to(:track_submission_success)
      expect(monitor).to respond_to(:track_submission_retry)
      expect(monitor).to respond_to(:track_submission_exhaustion)
    end
  end

  describe '#track_request_validation_error' do
    let(:request) do
      instance_double(
        Rack::Request,
        path: '/v0/form214192',
        request_method: 'POST',
        env: { 'SOURCE_APP' => '21-4192-employment-information' }
      )
    end

    context 'with pattern mismatch error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: '#/properties/veteranInformation/properties/ssn pattern ^\\d{9}$ does not match value'
        )
      end

      it 'increments StatsD metric with correct tags' do
        expect(StatsD).to receive(:increment).with(
          "#{claim_stats_key}.validation_error",
          hash_including(tags: array_including('service:form214192'))
        )

        monitor.track_request_validation_error(error:, request:)
      end

      it 'logs validation error with warn level' do
        expect(Rails.logger).to receive(:warn).with(
          "Form214192::Monitor #{form_id} Committee validation failed",
          hash_including(
            context: hash_including(
              form_id:,
              path: '/v0/form214192',
              method: 'POST',
              source_app: '21-4192-employment-information',
              error_type: 'pattern_mismatch',
              data_pointer: kind_of(String)
            )
          )
        )

        monitor.track_request_validation_error(error:, request:)
      end

      it 'extracts error_type as pattern_mismatch' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('pattern_mismatch')
        end

        monitor.track_request_validation_error(error:, request:)
      end

      it 'does not include PII in logs' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |message, payload|
          # Ensure no SSN patterns in logged data
          expect(message).not_to match(/\d{3}-\d{2}-\d{4}/)
          expect(message).not_to match(/\d{9}/)
          expect(payload[:context].to_s).not_to match(/\d{3}-\d{2}-\d{4}/)
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with missing required field error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'object at `/veteranInformation` is missing required properties: fullName'
        )
      end

      it 'extracts error_type as missing_required' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('missing_required')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with type mismatch error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'expected string, got integer'
        )
      end

      it 'extracts error_type as type_mismatch' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('type_mismatch')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with invalid enum error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: '"XX" is not a member of enum'
        )
      end

      it 'extracts error_type as invalid_enum' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('invalid_enum')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with length validation error' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'string length is greater than maxLength: 50'
        )
      end

      it 'extracts error_type as invalid_length' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('invalid_length')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'with unknown error type' do
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'Some other validation error'
        )
      end

      it 'extracts error_type as validation_error' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:error_type]).to eq('validation_error')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'when source app is not provided' do
      let(:request) do
        instance_double(
          Rack::Request,
          path: '/v0/form214192',
          request_method: 'POST',
          env: {}
        )
      end
      let(:error) do
        instance_double(
          Committee::InvalidRequest,
          message: 'validation error'
        )
      end

      it 'defaults source_app to unknown' do
        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:source_app]).to eq('unknown')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end

    context 'data pointer extraction' do
      let(:request) do
        instance_double(
          Rack::Request,
          path: '/v0/form214192',
          request_method: 'POST',
          env: {}
        )
      end

      it 'extracts field path from schema reference' do
        error = instance_double(
          Committee::InvalidRequest,
          message: '#/properties/veteranInformation/properties/fullName/properties/first required'
        )

        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          # Path is cleaned up to remove 'properties/' but keeps relative structure
          expect(payload[:context][:data_pointer]).to match(%r{veteranInformation/fullName/first})
        end

        monitor.track_request_validation_error(error:, request:)
      end

      it 'handles messages without field path' do
        error = instance_double(
          Committee::InvalidRequest,
          message: 'validation error with no path'
        )

        allow(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:warn) do |_, payload|
          expect(payload[:context][:data_pointer]).to eq('unknown')
        end

        monitor.track_request_validation_error(error:, request:)
      end
    end
  end

  describe '#track_submission_begun' do
    let(:claim) { SavedClaim::Form214192.new(form: '{}', guid: SecureRandom.uuid) }
    let(:user_uuid) { 'test-user-uuid-123' }

    it 'increments StatsD metric' do
      expect(StatsD).to receive(:increment).with(
        "#{claim_stats_key}.submission.begun",
        hash_including(tags: array_including('service:form214192'))
      )

      monitor.track_submission_begun(claim, user_uuid:)
    end

    it 'logs at info level with claim context' do
      expect(Rails.logger).to receive(:info).with(
        anything,
        hash_including(
          context: hash_including(
            user_uuid:,
            claim_guid: claim.guid
          )
        )
      )

      monitor.track_submission_begun(claim, user_uuid:)
    end

    it 'works without user_uuid' do
      expect(StatsD).to receive(:increment)
      expect(Rails.logger).to receive(:info)

      monitor.track_submission_begun(claim)
    end
  end

  describe '#track_submission_success' do
    let(:claim) { SavedClaim::Form214192.new(form: '{}', guid: SecureRandom.uuid) }
    let(:user_uuid) { 'test-user-uuid-456' }

    it 'increments StatsD metric' do
      expect(StatsD).to receive(:increment).with(
        "#{claim_stats_key}.submission.success",
        hash_including(tags: array_including('service:form214192'))
      )

      monitor.track_submission_success(claim, user_uuid:)
    end

    it 'logs at info level with claim context' do
      expect(Rails.logger).to receive(:info).with(
        anything,
        hash_including(
          context: hash_including(
            user_uuid:,
            claim_guid: claim.guid
          )
        )
      )

      monitor.track_submission_success(claim, user_uuid:)
    end
  end

  describe '#track_submission_failure' do
    let(:claim) { SavedClaim::Form214192.new(form: '{}', guid: SecureRandom.uuid) }
    let(:error) { StandardError.new('Test error message') }
    let(:user_uuid) { 'test-user-uuid-789' }

    it 'increments StatsD metric' do
      expect(StatsD).to receive(:increment).with(
        "#{claim_stats_key}.submission.failure",
        hash_including(tags: array_including('service:form214192'))
      )

      monitor.track_submission_failure(claim, error, user_uuid:)
    end

    it 'logs at error level with error context' do
      expect(Rails.logger).to receive(:error).with(
        anything,
        hash_including(
          context: hash_including(
            user_uuid:,
            claim_guid: claim.guid,
            error: error.message
          )
        )
      )

      monitor.track_submission_failure(claim, error, user_uuid:)
    end
  end

  describe '#track_request_code' do
    it 'increments StatsD metric' do
      allow(Rails.logger).to receive(:info)

      expect(StatsD).to receive(:increment).with(
        "#{claim_stats_key}.request",
        hash_including(tags: array_including('service:form214192'))
      )

      monitor.track_request_code(200, action: 'create', user_uuid: 'test-uuid')
    end

    it 'logs at info level with request context' do
      allow(StatsD).to receive(:increment)

      expect(Rails.logger).to receive(:info).with(
        anything,
        hash_including(
          context: hash_including(
            code: 200,
            action: 'create',
            user_uuid: 'test-user-uuid'
          )
        )
      )

      monitor.track_request_code(200, action: 'create', user_uuid: 'test-user-uuid')
    end

    it 'works with minimal parameters' do
      allow(Rails.logger).to receive(:info)

      expect(StatsD).to receive(:increment).with(
        "#{claim_stats_key}.request",
        anything
      )

      monitor.track_request_code(422)
    end

    it 'includes action in context when provided' do
      allow(StatsD).to receive(:increment)

      expect(Rails.logger).to receive(:info) do |_, payload|
        expect(payload[:context][:action]).to eq('download_pdf')
      end

      monitor.track_request_code(500, action: 'download_pdf')
    end

    it 'includes claim_guid in context when provided' do
      allow(StatsD).to receive(:increment)
      claim_guid = SecureRandom.uuid

      expect(Rails.logger).to receive(:info) do |_, payload|
        expect(payload[:context][:claim_guid]).to eq(claim_guid)
      end

      monitor.track_request_code(200, claim_guid:)
    end
  end
end
