# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAuditLogger do
  describe '#perform' do
    let(:user_action_event) { create(:user_action_event) }
    let(:acting_user_verification) { create(:user_verification) }
    let(:subject_user_verification) { create(:user_verification) }
    let(:acting_ip_address) { Faker::Internet.ip_v4_address }
    let(:acting_user_agent) { Faker::Internet.user_agent }
    let(:status) { :initial }
    let(:logger) do
      described_class.new(
        user_action_event:,
        acting_user_verification:,
        subject_user_verification:,
        status:,
        acting_ip_address:,
        acting_user_agent:
      )
    end

    it 'creates a user action record' do
      expect { logger.perform }.to change(UserAction, :count).by(1)

      user_action = UserAction.last
      expect(user_action).to have_attributes(
        user_action_event: user_action_event,
        acting_user_verification: acting_user_verification,
        subject_user_verification: subject_user_verification,
        status: 'initial',
        acting_ip_address: acting_ip_address,
        acting_user_agent: acting_user_agent
      )
    end

    context 'when user_action_event is nil' do
      let(:user_action_event) { nil }

      it 'raises a missing user action event error' do
        expect { logger.perform }.to raise_error(
          UserAuditLogger::MissingUserActionEventError,
          'User action event must be present'
        )
      end
    end

    context 'when subject_user_verification is nil' do
      let(:subject_user_verification) { nil }

      it 'raises a missing verification error' do
        expect { logger.perform }.to raise_error(
          UserAuditLogger::MissingSubjectVerificationError,
          'Subject user verification must be present'
        )
      end
    end

    context 'when status is nil' do
      let(:status) { nil }

      it 'raises a missing status error' do
        expect { logger.perform }.to raise_error(
          UserAuditLogger::MissingStatusError,
          'Status must be present'
        )
      end
    end

    context 'when required parameter is not provided' do
      it 'raises an argument error' do
        expect do
          described_class.new(
            user_action_event:,
            subject_user_verification:
          )
        end.to raise_error(ArgumentError, /missing keywords: :acting_user_verification/)
      end
    end
  end
end
