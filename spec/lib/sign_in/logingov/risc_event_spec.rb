# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/logingov/risc_event'

Rspec.describe SignIn::Logingov::RiscEvent do
  subject(:risc_event) { described_class.new(event:) }
  let(:event) { risc_event_payload[:events] }
  let(:risc_event_payload) { {} }

  describe 'validations' do
    shared_examples 'an invalid risc_event' do
      it 'is invalid' do
        expect(risc_event).not_to be_valid
        expect(risc_event.errors[error_attribute].first).to include(expected_error)
      end
    end

    context 'when risc_event is valid' do
      context 'when risc event is account-disabled' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :account_disabled) }

        it { is_expected.to be_valid }
      end

      context 'when risc event is account-enabled' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :account_enabled) }

        it { is_expected.to be_valid }
      end

      context 'when risc event is mfa-limit-account-locked' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :mfa_limit_account_locked) }

        it { is_expected.to be_valid }
      end

      context 'when risc event is account-purged' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :account_purged) }

        it { is_expected.to be_valid }
      end

      context 'when risc event is identifier-changed' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :identifier_changed) }

        it { is_expected.to be_valid }
      end

      context 'when risc event is identifier-recycled' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :identifier_recycled) }

        it { is_expected.to be_valid }
      end

      context 'when risc event is password-reset' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :password_reset) }

        it { is_expected.to be_valid }
      end

      context 'when risc event is recovery-activated' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :recovery_activated) }

        it { is_expected.to be_valid }
      end

      context 'when risc event is recovery-information-changed' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :recovery_information_changed) }

        it { is_expected.to be_valid }
      end

      context 'when risc event is reproof-completed' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :reproof_completed) }

        it { is_expected.to be_valid }
      end

      context 'when event_occurred_at is missing' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :account_disabled, event_occurred_at: nil) }

        before do
          Timecop.freeze(Time.current)
        end

        after do
          Timecop.return
        end

        it 'sets event_occurred_at to current time' do
          expect(risc_event.event_occurred_at).to eq(Time.current)
        end
      end

      context 'when reason is present' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :account_disabled, reason: 'some reason') }

        it 'sets reason' do
          expect(risc_event.reason).to eq('some reason')
        end
      end
    end

    context 'when risc_event is invalid' do
      context 'when event_type is missing' do
        let(:risc_event_payload) { build(:logingov_risc_event_payload, :account_disabled, event_type: nil) }
        let(:error_attribute) { :event_type }
        let(:expected_error) { "can't be blank" }
        let(:event_type) { nil }

        it_behaves_like 'an invalid risc_event'
      end

      context 'when event_type is unsupported' do
        let(:risc_event_payload) do
          build(:logingov_risc_event_payload, :account_disabled, event_type: 'unsupported_event')
        end
        let(:error_attribute) { :event_type }
        let(:event_type) { 'unsupported_event' }
        let(:expected_error) { 'is not included in the list' }
      end

      context 'when both email and logingov_uuid are missing' do
        let(:risc_event_payload) do
          build(:logingov_risc_event_payload, :account_disabled, email: nil, logingov_uuid: nil)
        end
        let(:error_attribute) { :base }
        let(:expected_error) { 'email or logingov_uuid must be present' }

        it_behaves_like 'an invalid risc_event'
      end
    end
  end

  describe 'to_h_masked' do
    let(:risc_event_payload) { build(:logingov_risc_event_payload, :account_disabled, :identifier_changed) }

    it 'masks the email address' do
      expect(risc_event.to_h_masked).to include(email: '[FILTERED]')
    end
  end
end
