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
    let(:mock_form_error) { 'Mock form validation error' }

    let(:claim_with_save_error) do
      claim = SavedClaim::DisabilityCompensation::Form526AllClaim.new
      errors = ActiveModel::Errors.new(claim)
      errors.add(:form, mock_form_error)
      allow(claim).to receive_messages(errors:)
      claim
    end

    it 'logs the error metadata' do
      expect(monitor).to receive(:submit_event).with(
        :error,
        "#{described_class} Form526 SavedClaim save error",
        described_class::CLAIM_STATS_KEY,
        form_id: '21-526EZ-ALLCLAIMS',
        in_progress_form_id: in_progress_form.id,
        errors: [{ form: mock_form_error }].to_s,
        user_account_uuid: user.uuid
      )

      monitor.track_saved_claim_save_error(
        claim_with_save_error.errors.errors,
        in_progress_form.id,
        user.uuid
      )
    end

    # NOTE: in_progress_form_id, user_account_uuid, and errors keys are whitelisted payload keys
    # for monitors inheriting from Logging::BaseMonitor; ensures this information will not be filtered out when it is
    # written to the Rails logger; see config/initializers/filter_parameter_logging.rb
    it 'does not filter out error details when writing to the Rails logger' do
      expect(Rails.logger).to receive(:error) do |_, payload|
        expect(payload[:context][:user_account_uuid]).to eq(user.uuid)
        expect(payload[:context][:errors]).to eq([{ form: mock_form_error }].to_s)
        expect(payload[:context][:in_progress_form_id]).to eq(in_progress_form.id)
      end

      monitor.track_saved_claim_save_error(
        claim_with_save_error.errors,
        in_progress_form.id,
        user.uuid
      )
    end
  end
end
