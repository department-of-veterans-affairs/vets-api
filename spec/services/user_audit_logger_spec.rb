# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAuditLogger do
  describe '#perform' do
    let(:user_action_event) { create(:user_action_event) }
    let(:acting_user_verification) { create(:user_verification) }
    let(:subject_user_verification) { create(:user_verification) }
    let(:ip_address) { Faker::Internet.ip_v4_address }
    let(:user_agent) { Faker::Internet.user_agent }
    let(:config) do
      {
        user_action_event: user_action_event,
        acting_user_verification: acting_user_verification,
        subject_user_verification: subject_user_verification,
        status: :initial,
        ip_address: ip_address,
        user_agent: user_agent
      }
    end
    let(:logger) { described_class.new(config) }

    it 'creates a user action record' do
      expect { logger.perform }.to change(UserAction, :count).by(1)

      user_action = UserAction.last
      expect(user_action).to have_attributes(
        user_action_event: user_action_event,
        acting_user_verification: acting_user_verification,
        subject_user_verification: subject_user_verification,
        status: 'initial',
        acting_ip_address: ip_address,
        acting_user_agent: user_agent
      )
    end

    it 'allows setting different status values' do
      config = {
        user_action_event: user_action_event,
        acting_user_verification: acting_user_verification,
        subject_user_verification: subject_user_verification,
        status: :error
      }

      logger = described_class.new(config)
      user_action = logger.perform

      expect(user_action.status).to eq('error')
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
          'Subject user must have a verification'
        )
      end
    end

    context 'when status is nil' do
      let(:config) do
        {
          user_action_event: user_action_event,
          acting_user_verification: acting_user_verification,
          subject_user_verification: subject_user_verification,
          status: nil
        }
      end

      it 'raises a missing status error' do
        expect { logger.perform }.to raise_error(
          UserAuditLogger::MissingStatusError,
          'Status must be present'
        )
      end
    end

    context 'when required parameter is not provided' do
      it 'raises a key error' do
        config = {
          user_action_event: user_action_event,
          acting_user_verification: acting_user_verification,
          subject_user_verification: subject_user_verification
          # status is missing
        }

        expect { described_class.new(config) }.to raise_error(KeyError, /key not found: :status/)
      end
    end
  end
end
