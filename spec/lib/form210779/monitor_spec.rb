# frozen_string_literal: true

require 'rails_helper'
require 'form210779/monitor'

RSpec.describe Form210779::Monitor do
  subject(:monitor) { described_class.new }

  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:form_id) { described_class::FORM_ID }

  describe 'BaseMonitor abstract methods' do
    it 'implements required methods' do
      expect(monitor.claim_stats_key).to eq('api.form210779')
      expect(monitor.name).to eq('form210779')
      expect(monitor.form_id).to eq('21-0779')
    end

    it 'has required tags' do
      expect(monitor.tags).to eq(['form_id:21-0779'])
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
        path: '/v0/form210779',
        request_method: 'POST',
        env: { 'SOURCE_APP' => '21-0779-nursing-home-information' }
      )
    end

    context 'with ActiveRecord validation error' do
      let(:claim) do
        claim = SavedClaim::Form210779.new
        claim.errors.add(:form, 'is invalid')
        claim
      end
      let(:error) { Common::Exceptions::ValidationErrors.new(claim) }

      it 'increments StatsD metric with correct tags' do
        expect(StatsD).to receive(:increment).with(
          "#{claim_stats_key}.validation_error",
          hash_including(tags: array_including('service:form210779'))
        )

        monitor.track_request_validation_error(error:, request:, claim:)
      end

      it 'logs validation error with field path' do
        expect(Rails.logger).to receive(:warn).with(
          "Form210779::Monitor #{form_id} validation failed: activerecord_validation",
          hash_including(
            context: hash_including(
              form_id:,
              error_type: 'activerecord_validation',
              data_pointer: 'form'
            )
          )
        )

        monitor.track_request_validation_error(error:, request:, claim:)
      end
    end
  end

  describe '#track_submission_begun' do
    let(:claim) { SavedClaim::Form210779.new(form: '{}', guid: SecureRandom.uuid) }
    let(:user_uuid) { 'test-user-uuid-123' }

    it 'increments StatsD metric' do
      expect(StatsD).to receive(:increment).with(
        "#{claim_stats_key}.submission.begun",
        hash_including(tags: array_including('service:form210779'))
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
    let(:claim) { SavedClaim::Form210779.new(form: '{}', guid: SecureRandom.uuid) }
    let(:user_uuid) { 'test-user-uuid-456' }

    it 'increments StatsD metric' do
      expect(StatsD).to receive(:increment).with(
        "#{claim_stats_key}.submission.success",
        hash_including(tags: array_including('service:form210779'))
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
    let(:claim) { SavedClaim::Form210779.new(form: '{}', guid: SecureRandom.uuid) }
    let(:error) { StandardError.new('Test error message') }
    let(:user_uuid) { 'test-user-uuid-789' }

    it 'increments StatsD metric' do
      expect(StatsD).to receive(:increment).with(
        "#{claim_stats_key}.submission.failure",
        hash_including(tags: array_including('service:form210779'))
      )

      monitor.track_submission_failure(claim, error, user_uuid:)
    end

    it 'logs at error level with error context' do
      expect(Rails.logger).to receive(:error).with(
        anything,
        hash_including(
          context: hash_including(
            user_uuid:,
            claim_guid: claim.guid
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
        hash_including(tags: array_including('service:form210779'))
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
