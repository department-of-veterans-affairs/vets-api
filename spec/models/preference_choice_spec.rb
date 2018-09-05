# frozen_string_literal: true

require 'rails_helper'

describe PreferenceChoice, type: :model do
  describe 'validations' do
    it 'has a valid factory' do
      preference_choice = build(:preference_choice)
      expect(preference_choice).to be_valid
    end
  end
end
