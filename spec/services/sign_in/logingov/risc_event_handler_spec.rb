# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::Logingov::RiscEventHandler, type: :service do
  subject(:handler) { described_class.new(payload:) }

  let(:payload) do
    build(
      :logingov_risc_event_payload,
      :identifier_changed,
      email:,
      logingov_uuid: nil,
      reason:,
      event_occurred_at:
    )
  end

  let(:event_type) { :identifier_changed }
  let(:email) { 'some-email@example.com' }
  let(:logingov_uuid) { nil }
  let(:reason) { 'User changed email' }
  let(:event_occurred_at) { Time.current }

  before do
    Timecop.freeze(event_occurred_at)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  after do
    Timecop.return
  end

  describe '#perform' do
    context 'when the event is valid' do
      let(:expected_log_message) { '[SignIn][Logingov][RiscEventHandler] risc_event received' }
      let(:expected_log_payload) do
        {
          risc_event: {
            event_type: :identifier_changed,
            email: '[FILTERED]',
            logingov_uuid:,
            reason:,
            event_occurred_at: event_occurred_at.iso8601
          }
        }
      end

      it 'logs the masked risc event receipt' do
        handler.perform

        expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
      end
    end

    context 'when validation fails' do
      let(:email) { nil }
      let(:logingov_uuid) { nil }
      let(:expected_log_payload) do
        {
          risc_event: {
            event_type: :identifier_changed,
            email:,
            logingov_uuid:,
            reason:,
            event_occurred_at: event_occurred_at.iso8601
          }
        }
      end
      let(:expected_log_message) { '[SignIn][Logingov][RiscEventHandler] validation error' }
      let(:error_message) do
        'Validation failed: email or logingov_uuid must be present'
      end

      it 'rescues and logs the validation error' do
        expect do
          handler.perform
        end.to raise_error(SignIn::Errors::LogingovRiscEventHandlerError, "Invalid RISC event: #{error_message}")

        expect(Rails.logger).to have_received(:error).with(expected_log_message,
                                                           { error: error_message }.merge(expected_log_payload))
      end
    end
  end
end
