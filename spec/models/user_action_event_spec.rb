# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEvent, type: :model do
  describe 'validations' do
    subject { build(:user_action_event) }

    it { is_expected.to validate_presence_of(:details) }
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_uniqueness_of(:event_id) }
    it { is_expected.to validate_presence_of(:event_type) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:event_type).with_values(authentication: 0, profile: 1) }

    describe 'event types' do
      let(:auth_event) { build(:user_action_event, event_type: :authentication) }
      let(:profile_event) { build(:user_action_event, event_type: :profile) }

      it 'allows setting authentication type' do
        expect(auth_event).to be_valid
        expect(auth_event).to be_authentication
      end

      it 'allows setting profile type' do
        expect(profile_event).to be_valid
        expect(profile_event).to be_profile
      end

      it 'prevents invalid event types' do
        expect { 
          build(:user_action_event, event_type: :invalid)
        }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'event_id format' do
    let(:event1) { create(:user_action_event) }
    let(:event2) { create(:user_action_event) }
    let(:auth_event) { create(:user_action_event, event_type: :authentication) }

    it 'generates unique event_ids' do
      expect(event1.event_id).not_to eq(event2.event_id)
    end

    it 'prefixes authentication events correctly' do
      expect(auth_event.event_id).to start_with('event_')
    end
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

  describe 'event_id validations' do
    let(:event) { build(:user_action_event) }
    
    it 'rejects duplicate event_ids' do
      create(:user_action_event, event_id: 'duplicate_id')
      duplicate_event = build(:user_action_event, event_id: 'duplicate_id')
      expect(duplicate_event).not_to be_valid
      expect(duplicate_event.errors[:event_id]).to include('has already been taken')
    end

    it 'is case sensitive with event_ids' do
      create(:user_action_event, event_id: 'TEST_ID')
      duplicate_event = build(:user_action_event, event_id: 'test_id')
      expect(duplicate_event).to be_valid
    end
  end

  describe 'event type transitions' do
    let(:event) { create(:user_action_event, event_type: :authentication) }

    it 'allows changing event type' do
      event.profile!
      expect(event).to be_profile
      expect(event).not_to be_authentication
    end

    it 'persists event type changes' do
      event.profile!
      event.reload
      expect(event).to be_profile
    end
  end

  describe 'scopes' do
    let!(:auth_event) { create(:user_action_event, event_type: :authentication) }
    let!(:profile_event) { create(:user_action_event, event_type: :profile) }

    it 'filters authentication events' do
      expect(described_class.authentication).to include(auth_event)
      expect(described_class.authentication).not_to include(profile_event)
    end

    it 'filters profile events' do
      expect(described_class.profile).to include(profile_event)
      expect(described_class.profile).not_to include(auth_event)
    end
  end

  describe 'data integrity' do
    let(:event) { build(:user_action_event) }

    it 'strips whitespace from event_id' do
      event.event_id = ' test_id '
      event.valid?
      expect(event.event_id).to eq('test_id')
    end

    it 'prevents changing event_id after creation' do
      event.save!
      original_id = event.event_id
      event.update(event_id: 'new_id')
      event.reload
      expect(event.event_id).to eq(original_id)
    end
  end
end
