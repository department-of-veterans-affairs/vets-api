# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/loggers/monitor'

RSpec.describe DisabilityCompensation::Loggers::Monitor do
  let(:monitor) { described_class.new }

  describe '#submit_event' do
    it 'logs with the appropriate key prefixes and metadata' do
      payload = { example_key: 'value' }
      expect(monitor).to receive(:track_request).with(
        :error,
        'Example message',
        described_class::CLAIM_STATS_KEY,
        call_location: anything,
        **payload
      )

      monitor.send(:submit_event, :error, 'Example message', described_class::CLAIM_STATS_KEY, payload)
    end
  end

  describe '#track_saved_claim_save_error' do
    let(:user) { double(uuid: '1234') }
    let(:in_progress_form_id) { 42 }
    let(:mock_claim) { double(errors: double(errors: [double(attribute: :form, type: 'invalid')])) }

    it 'submits the error with proper keys' do
      expect(monitor).to receive(:submit_event).with(
        :error,
        "#{described_class} Form526 SavedClaim save error",
        described_class::CLAIM_STATS_KEY,
        form_id: '21-526EZ-ALLCLAIMS',
        in_progress_form_id:,
        errors: [{ form: 'invalid' }].to_s,
        user_account_uuid: user.uuid
      )

      monitor.track_saved_claim_save_error(mock_claim.errors.errors, in_progress_form_id, user.uuid)
    end

    it 'handles empty errors array' do
      expect(monitor).to receive(:submit_event).with(
        :error,
        anything,
        anything,
        errors: [].to_s,
        in_progress_form_id:,
        user_account_uuid: user.uuid,
        form_id: '21-526EZ-ALLCLAIMS'
      )

      monitor.track_saved_claim_save_error([], in_progress_form_id, user.uuid)
    end
  end

  describe 'private helper methods' do
    it 'returns correct constants' do
      expect(monitor.send(:service_name)).to eq(described_class::SERVICE_NAME)
      expect(monitor.send(:claim_stats_key)).to eq(described_class::CLAIM_STATS_KEY)
      expect(monitor.send(:submission_stats_key)).to eq(described_class::SUBMISSION_STATS_KEY)
      expect(monitor.send(:name)).to eq(described_class.name)
      expect(monitor.send(:form_id)).to eq(described_class::FORM_ID)
    end
  end

  describe '#format_active_model_errors' do
    it 'formats multiple errors correctly' do
      errors = [
        double(attribute: :foo, type: :invalid),
        double(attribute: :bar, type: :blank)
      ]
      expect(monitor.send(:format_active_model_errors, errors)).to eq([{ foo: 'invalid' }, { bar: 'blank' }].to_s)
    end

    it 'formats empty errors array as string' do
      expect(monitor.send(:format_active_model_errors, [])).to eq([].to_s)
    end
  end
end
