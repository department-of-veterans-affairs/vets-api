# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAction, type: :model do
  describe 'validations' do
    let(:user_action) { build(:user_action) }

    it 'is valid with valid attributes' do
      expect(user_action).to be_valid
    end

    it 'is valid with nil acting_ip_address' do
      user_action.acting_ip_address = nil
      expect(user_action).to be_valid
    end

    it 'is valid with nil acting_user_agent' do
      user_action.acting_user_agent = nil
      expect(user_action).to be_valid
    end

    it 'is valid without acting_user_verification' do
      user_action.acting_user_verification = nil
      expect(user_action).to be_valid
    end

    describe '#status' do
      context 'when nil' do
        before { user_action.status = nil }

        it 'is not valid' do
          expect(user_action).not_to be_valid
          expect(user_action.errors[:status]).to include("can't be blank")
        end
      end

      context 'when invalid value' do
        it 'raises ArgumentError' do
          expect { user_action.status = 'invalid' }.to raise_error(ArgumentError, "'invalid' is not a valid status")
        end
      end

      %w[initial success error].each do |valid_status|
        context "when status is #{valid_status}" do
          before { user_action.status = valid_status }

          it 'is valid' do
            expect(user_action).to be_valid
          end
        end
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
  end

  describe 'factory traits' do
    describe ':system_initiated' do
      let(:system_action) { create(:user_action, :system_initiated) }

      it 'has nil acting_user_verification' do
        expect(system_action.acting_user_verification).to be_nil
      end

      it 'has nil acting_ip_address' do
        expect(system_action.acting_ip_address).to be_nil
      end

      it 'has nil acting_user_agent' do
        expect(system_action.acting_user_agent).to be_nil
      end

      it 'is valid' do
        expect(system_action).to be_valid
      end

      it 'still requires subject_user_verification' do
        expect(system_action.subject_user_verification).to be_present
      end
    end
  end
end
