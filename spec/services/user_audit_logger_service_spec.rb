# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAuditLoggerService do
  let(:details) { 'some details' }
  let(:acting_user_verification) { create(:user_verification) }
  let(:subject_user_verification) { create(:user_verification) }
  let(:status) { 'initial' }
  let(:acting_ip_address) { Faker::Internet.ip_v4_address }
  let(:acting_user_agent) { Faker::Internet.user_agent }

  describe '.log_user_action' do
    subject do
      described_class.log_user_action(details:,
                                      acting_user_verification:,
                                      subject_user_verification:,
                                      status:,
                                      acting_ip_address:,
                                      acting_user_agent:)
    end

    context 'with valid attributes' do
      context 'with missing acting_user_verification' do
        let(:acting_user_verification) { nil }

        it 'does not raise a validation error' do
          expect { subject }.not_to raise_error
        end
      end

      it 'creates a new UserActionEvent' do
        response = subject
        user_action_event = UserActionEvent.find(response.user_action_event_id)
        expect(user_action_event).to be_a(UserActionEvent)
        expect(user_action_event).to be_valid
        expect(user_action_event.details).to eq(details)
      end

      it 'creates a new UserAction' do
        response = subject
        expect(response).to be_a(UserAction)
        expect(response).to be_valid
      end
    end

    context 'with invalid attributes' do
      context 'with missing details' do
        let(:details) { nil }
        let(:expected_error_message) { 'Validation failed: Details can\'t be blank' }

        it 'raises a validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end

      context 'with missing subject_user_verification' do
        let(:subject_user_verification) { nil }
        let(:expected_error_message) { 'Validation failed: Subject user verification must exist' }

        it 'raises a validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end

      context 'with missing status' do
        let(:status) { nil }
        let(:expected_error_message) { 'Validation failed: Status is not included in the list' }

        it 'raises a validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end

      context 'with an invalid status' do
        let(:status) { 'some-status' }
        let(:expected_error_message) { 'Validation failed: Status is not included in the list' }

        it 'raises a validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end
    end
  end
end
