# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAuditLogger do
  describe '.log' do
    let(:acting_user) { build(:user) }
    let(:subject_user) { build(:user) }
    let(:user_action_event) { create(:user_action_event) }
    let(:acting_user_verification) { create(:user_verification) }
    let(:subject_user_verification) { create(:user_verification) }
    let(:ip_address) { Faker::Internet.ip_v4_address }
    let(:user_agent) { Faker::Internet.user_agent }

    before do
      allow(acting_user).to receive(:user_verification).and_return(acting_user_verification)
      allow(subject_user).to receive(:user_verification).and_return(subject_user_verification)
    end

    it 'creates a user action record' do
      expect do
        described_class.log(
          user_action_event_id: user_action_event.id,
          acting_user: acting_user,
          subject_user: subject_user,
          ip_address: ip_address,
          user_agent: user_agent
        )
      end.to change(UserAction, :count).by(1)

      user_action = UserAction.last
      expect(user_action).to have_attributes(
        user_action_event_id: user_action_event.id,
        acting_user_verification: acting_user_verification,
        subject_user_verification: subject_user_verification,
        status: 'initial',
        acting_ip_address: ip_address,
        acting_user_agent: user_agent
      )
    end

    it 'allows setting a custom status' do
      user_action = described_class.log(
        user_action_event_id: user_action_event.id,
        acting_user: acting_user,
        subject_user: subject_user,
        status: :success
      )

      expect(user_action.status).to eq('success')
    end

    context 'when subject_user has no verification' do
      before do
        allow(subject_user).to receive(:user_verification).and_return(nil)
      end

      it 'raises a missing verification error' do
        expect do
          described_class.log(
            user_action_event_id: user_action_event.id,
            acting_user: acting_user,
            subject_user: subject_user
          )
        end.to raise_error(
          UserAuditLogger::MissingSubjectVerificationError,
          'Subject user must have a verification'
        )
      end
    end
  end
end
