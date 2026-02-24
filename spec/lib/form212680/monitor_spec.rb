# frozen_string_literal: true

require 'rails_helper'
require 'form212680/monitor'

RSpec.describe Form212680::Monitor do
  subject(:monitor) { described_class.new }

  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:form_id) { described_class::FORM_ID }

  describe 'BaseMonitor abstract methods' do
    it 'implements required methods' do
      expect(monitor.claim_stats_key).to eq('api.form212680')
      expect(monitor.submission_stats_key).to eq('worker.lighthouse.form212680_intake_job')
      expect(monitor.name).to eq('form212680')
      expect(monitor.form_id).to eq('21-2680')
    end

    it 'has required tags' do
      expect(monitor.tags).to eq(['form_id:21-2680'])
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
        path: '/v0/form212680',
        request_method: 'POST',
        env: { 'SOURCE_APP' => '21-2680-housebound-status' }
      )
    end

    context 'with ActiveRecord validation error' do
      let(:claim) do
        claim = SavedClaim::Form212680.new
        claim.errors.add(:form, 'is invalid')
        claim
      end
      let(:error) { Common::Exceptions::ValidationErrors.new(claim) }

      it 'increments StatsD metric with correct tags' do
        expect(StatsD).to receive(:increment).with(
          "#{claim_stats_key}.validation_error",
          hash_including(tags: array_including('service:form212680'))
        )

        monitor.track_request_validation_error(error:, request:, claim:)
      end

      it 'logs validation error with field path' do
        expect(Rails.logger).to receive(:warn).with(
          "Form212680::Monitor #{form_id} validation failed: activerecord_validation",
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
end
