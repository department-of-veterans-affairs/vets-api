# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAction, type: :model do
  describe 'validations' do
    let(:user_action) { build(:user_action) }

    it 'is valid with valid attributes' do
      expect(user_action).to be_valid
    end

    describe '#acting_ip_address' do
      context 'when nil' do
        before { user_action.acting_ip_address = nil }

        it 'is not valid' do
          expect(user_action).not_to be_valid
          expect(user_action.errors[:acting_ip_address]).to include("can't be blank")
        end
      end
    end

    describe '#acting_user_agent' do
      context 'when nil' do
        before { user_action.acting_user_agent = nil }

        it 'is not valid' do
          expect(user_action).not_to be_valid
          expect(user_action.errors[:acting_user_agent]).to include("can't be blank")
        end
      end
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
    let(:user_action) { create(:user_action) }

    it 'belongs to acting_user_account' do
      expect(user_action.acting_user_account).to be_a(UserAccount)
    end

    it 'belongs to subject_user_account' do
      expect(user_action.subject_user_account).to be_a(UserAccount)
    end

    it 'belongs to user_action_event' do
      expect(user_action.user_action_event).to be_a(UserActionEvent)
    end

    context 'with subject_user_verification' do
      let(:user_action) { create(:user_action, :with_verification) }

      it 'can have an optional subject_user_verification' do
        expect(user_action.subject_user_verification).to be_a(UserVerification)
      end
    end
  end

  describe 'enum status' do
    let(:user_action) { create(:user_action) }

    it 'defines status predicates' do
      expect(user_action).to respond_to(:status_initial?)
      expect(user_action).to respond_to(:status_success?)
      expect(user_action).to respond_to(:status_error?)
    end
  end

  describe 'factory traits' do
    describe ':success_status' do
      let(:user_action) { create(:user_action, :success_status) }

      it 'sets the status to success' do
        expect(user_action.status).to eq('success')
        expect(user_action).to be_status_success
      end
    end

    describe ':error_status' do
      let(:user_action) { create(:user_action, :error_status) }

      it 'sets the status to error' do
        expect(user_action.status).to eq('error')
        expect(user_action).to be_status_error
      end
    end
  end

  describe 'status transitions' do
    let(:user_action) { create(:user_action) }

    it 'starts with initial status' do
      expect(user_action).to be_status_initial
    end

    it 'can transition from initial to success' do
      user_action.status = 'success'
      expect(user_action).to be_valid
      expect(user_action).to be_status_success
    end

    it 'can transition from initial to error' do
      user_action.status = 'error'
      expect(user_action).to be_valid
      expect(user_action).to be_status_error
    end
  end
end 