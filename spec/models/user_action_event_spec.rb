# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEvent, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:details) }
  end

  describe 'associations' do
    let(:user_action_event) { create(:user_action_event) }

    it { is_expected.to have_many(:user_actions).dependent(:restrict_with_exception) }

    context 'when user actions exist' do
      let!(:user_action) { create(:user_action, user_action_event: user_action_event) }

      it 'restricts destruction when user actions exist' do
        expect { user_action_event.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid user action event' do
      event = build(:user_action_event)
      expect(event).to be_valid
    end

    it 'creates unique event_ids' do
      event1 = create(:user_action_event)
      event2 = create(:user_action_event)
      expect(event1.event_id).not_to eq(event2.event_id)
    end

    it 'creates authentication events' do
      event = create(:user_action_event, :authentication)
      expect(event.event_type).to eq(0)
      expect(event.event_id).to start_with('auth_')
    end

    it 'creates profile events' do
      event = create(:user_action_event, :profile)
      expect(event.event_type).to eq(1)
      expect(event.event_id).to start_with('profile_')
    end
  end
end
