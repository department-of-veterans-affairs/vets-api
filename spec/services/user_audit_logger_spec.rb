# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAuditLogger do
  describe '#perform' do
    let(:user_action_event) { create(:user_action_event) }
    let(:user_action_event_identifier) { user_action_event&.identifier }
    let(:user_action) { create(:user_action, user_action_event:) }
    let(:acting_user_verification) { create(:user_verification) }
    let(:subject_user_verification) { create(:user_verification) }
    let(:acting_ip_address) { Faker::Internet.ip_v4_address }
    let(:acting_user_agent) { Faker::Internet.user_agent }
    let(:status) { :initial }
    let(:logger) do
      described_class.new(
        user_action_event_identifier:,
        acting_user_verification:,
        subject_user_verification:,
        status:,
        acting_ip_address:,
        acting_user_agent:
      )
    end

    context 'when the job is successful' do
      let(:expected_audit_log) { 'User audit log created' }

      before do
        allow(Rails.logger).to receive(:info).and_call_original
      end

      it 'creates a user action record' do
        expect { logger.perform }.to change(UserAction, :count).by(1)

        user_action = UserAction.last
        expect(user_action).to have_attributes(
          user_action_event:,
          acting_user_verification:,
          subject_user_verification:,
          status: 'initial',
          acting_ip_address:,
          acting_user_agent:
        )
      end

      it 'creates a rails log' do
        user_action = logger.perform
        expected_audit_log_payload = { user_action_event: user_action_event.id,
                                       user_action_event_details: user_action_event.details,
                                       status: :initial,
                                       user_action: user_action.id }
        expect(Rails.logger).to have_received(:info).with(expected_audit_log, expected_audit_log_payload)
      end

      context 'when acting_user_verification is nil' do
        let(:acting_user_verification) { nil }

        it 'lists the subject_user_verification as the acting_user_verification' do
          user_action = logger.perform
          expect(user_action.subject_user_verification).to eq(subject_user_verification)
        end
      end

      context 'when acting_user_verification is provided' do
        it 'uses the provided acting_user_verification' do
          user_action = logger.perform
          expect(user_action.acting_user_verification).to eq(acting_user_verification)
        end
      end
    end

    context 'when the job is unsuccessful' do
      let(:expected_log_message) { '[UserAuditLogger] error' }

      shared_examples 'error logging' do
        it 'logs an error message' do
          expect(Rails.logger).to receive(:error).with(expected_log_message, { error: expected_error })
          logger.perform
        end
      end

      context 'when user_action_event_identifier is nil' do
        let(:user_action_event_identifier) { nil }
        let(:expected_error) { 'undefined method `id\' for nil' }

        it_behaves_like 'error logging'
      end

      context 'when subject_user_verification is nil' do
        let(:subject_user_verification) { nil }
        let(:expected_error) { 'undefined method `validate!\' for nil' }

        it_behaves_like 'error logging'
      end

      context 'when status is nil' do
        let(:status) { nil }
        let(:expected_error) { 'Validation failed: Status is not included in the list' }

        it_behaves_like 'error logging'
      end

      context 'when one or more required parameters are not provided' do
        let(:expected_error) { 'missing keywords: :status, :acting_user_agent' }

        it 'raises an argument error' do
          expect do
            described_class.new(
              user_action_event_identifier:,
              subject_user_verification:,
              acting_ip_address:
            )
          end.to raise_error(ArgumentError, expected_error)
        end
      end
    end
  end
end
