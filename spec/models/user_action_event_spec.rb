# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEvent, type: :model do
  describe 'validations' do
    describe '#details' do
      context 'when details is nil' do
        let(:user_action_event) { build(:user_action_event, details: nil) }

        it 'is not valid' do
          expect(user_action_event).not_to be_valid
          expect(user_action_event.errors[:details]).to include("can't be blank")
        end
      end

      context 'when details is present' do
        let(:user_action_event) { build(:user_action_event, details: 'User logged in') }

        it 'is valid' do
          expect(user_action_event).to be_valid
        end
      end
    end
  end

  describe 'associations' do
    describe '#user_actions' do
      let(:user_action_event) { create(:user_action_event) }
      let!(:user_action) { create(:user_action, user_action_event: user_action_event) }

      it 'has associated user actions' do
        expect(user_action_event.user_actions).to include(user_action)
      end

      it 'restricts destruction when user actions exist' do
        expect { user_action_event.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
      end
    end
  end
end 