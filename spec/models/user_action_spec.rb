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

    context 'when attributes are valid' do
      it 'is valid' do
        expect(user_action).to be_valid
      end
    end

    context 'when acting_ip_address is nil' do
      let(:acting_ip_address) { nil }

      it 'is valid' do
        expect(user_action).to be_valid
      end
    end

    context 'when acting_user_agent is nil' do
      let(:acting_user_agent) { nil }

      it 'is valid' do
        expect(user_action).to be_valid
      end
    end

    context 'when acting_user_verification is nil' do
      let(:acting_user_verification) { nil }

      it 'is valid' do
        expect(user_action).to be_valid
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:acting_user_verification).class_name('UserVerification').optional }
    it { is_expected.to belong_to(:subject_user_verification).class_name('UserVerification') }
    it { is_expected.to belong_to(:user_action_event) }
  end

  describe 'enum status' do
    let(:user_action) { create(:user_action) }

    it 'defines status predicates' do
      expect(user_action).to respond_to(:initial?)
      expect(user_action).to respond_to(:success?)
      expect(user_action).to respond_to(:error?)
    end

    it 'defines the expected status values' do
      expect(described_class.statuses).to eq(
        'initial' => 'initial',
        'success' => 'success',
        'error' => 'error'
      )
    end

    %w[initial success error].each do |valid_status|
      context "when status is #{valid_status}" do
        let(:user_action) { build(:user_action, status: valid_status) }

        it 'is valid' do
          expect(user_action).to be_valid
        end
      end
    end
  end
end