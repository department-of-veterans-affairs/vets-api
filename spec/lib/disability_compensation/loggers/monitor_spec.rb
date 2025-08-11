# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/loggers/monitor'

RSpec.describe DisabilityCompensation::Loggers::Monitor do
  let(:monitor) { described_class.new }

  # Simple test to ensure monitor successfully implements abstract methods in lib/logging/base_monitor.rb
  describe('#submit_event') do
    it 'logs with the appropriate Disability Compensation key prefixes and metadata' do
      payload = {
        confirmation_number: nil,
        user_account_uuid: '1234',
        claim_id: '1234',
        form_id: described_class::FORM_ID,
        tags: [],
        additional_context_key: 'value'
      }

      expect(monitor).to receive(:track_request).with(
        :error,
        'Example message',
        described_class::CLAIM_STATS_KEY,
        call_location: anything,
        **payload
      )

      monitor.send(
        :submit_event,
        :error,
        'Example message',
        described_class::CLAIM_STATS_KEY,
        payload
      )
    end
  end

  describe('#track_saved_claim_save_error') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }
    let(:in_progress_form) { create(:in_progress_form) }

    let(:error_details) { { base: [{ error: :invalid }] } }
    let(:error_messages) { ['Base is invalid', 'Other Error Message'] }

    let(:mock_errors) do
      instance_double(
        ActiveModel::Errors,
        details: error_details,
        full_messages: error_messages
      )
    end

    it 'logs the error metadata' do
      expect(monitor).to receive(:submit_event).with(
        :error,
        "#{described_class} Form526 SavedClaim save error",
        described_class::CLAIM_STATS_KEY,
        in_progress_form_id: in_progress_form.id,
        user_uuid: user.uuid,
        error_details: error_details.to_s,
        error_messages: error_messages.to_s
      )

      monitor.track_saved_claim_save_error(
        mock_errors,
        in_progress_form.id,
        user.uuid
      )
    end
  end
end
