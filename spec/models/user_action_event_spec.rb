# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActionEvent, type: :model do
  describe 'validations' do
    subject { create(:user_action_event) }

    it { is_expected.to validate_presence_of(:details) }
    it { is_expected.to validate_presence_of(:identifier) }
    it { is_expected.to validate_uniqueness_of(:identifier) }
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to have_many(:user_actions).dependent(:restrict_with_exception) }
  end
end
