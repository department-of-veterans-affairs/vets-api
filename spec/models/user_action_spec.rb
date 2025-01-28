# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAction, type: :model do
  describe 'validations' do
    let(:acting_ip_address) { Faker::Internet.ip_v4_address }
    let(:acting_user_agent) { Faker::Internet.user_agent }
    let(:acting_user_verification) { build(:user_verification) }
    let(:user_action) do
      build(:user_action,
            acting_ip_address:,
            acting_user_agent:,
            acting_user_verification:)
    end

    it 'is valid with valid attributes' do
      expect(user_action).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:acting_user_verification).class_name('UserVerification').optional }
    it { is_expected.to belong_to(:subject_user_verification).class_name('UserVerification') }
    it { is_expected.to belong_to(:user_action_event) }
  end

  describe 'enum status' do
    let(:user_action) { build(:user_action) }

    it 'defines the expected status values' do
      expect(described_class.statuses).to eq(
        'initial' => 'initial',
        'success' => 'success',
        'error' => 'error'
      )
    end

    it 'validates inclusion of status' do
      user_action.status = 'invalid_status'
      expect(user_action).not_to be_valid
      expect(user_action.errors[:status]).to include('is not included in the list')
    end
  end
end
