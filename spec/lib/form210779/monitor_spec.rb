# frozen_string_literal: true

require 'rails_helper'
require 'form210779/monitor'

RSpec.describe Form210779::Monitor do
  subject(:monitor) { described_class.new }

  let(:claim_stats_key) { described_class::CLAIM_STATS_KEY }
  let(:submission_stats_key) { described_class::SUBMISSION_STATS_KEY }
  let(:form_id) { described_class::FORM_ID }

  describe 'BaseMonitor abstract methods' do
    it 'implements required methods' do
      expect(monitor.claim_stats_key).to eq('api.form210779')
      expect(monitor.submission_stats_key).to eq('worker.lighthouse.form210779_intake_job')
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
end
