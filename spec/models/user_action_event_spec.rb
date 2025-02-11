# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEvent, type: :model do
  describe 'validations' do
    subject { build(:user_action_event) }

    it { is_expected.to validate_presence_of(:details) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_uniqueness_of(:slug) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:event_type).with_values(authentication: 0, profile: 1) }
  end

  describe 'associations' do
    let(:user_action_event) { create(:user_action_event, slug: "test_#{SecureRandom.hex(4)}") }

    it { is_expected.to have_many(:user_actions).dependent(:restrict_with_exception) }

    context 'when user actions exist' do
      let!(:user_action) { create(:user_action, user_action_event: user_action_event) }

      it 'restricts destruction when user actions exist' do
        expect { user_action_event.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
      end
    end
  end
end
