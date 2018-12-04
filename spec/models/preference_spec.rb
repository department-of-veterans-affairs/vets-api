# frozen_string_literal: true

require 'rails_helper'

describe Preference do
  it 'has a valid factory' do
    preference = build(:preference)
    expect(preference).to be_valid
  end

  describe '#to_param' do
    it 'returns the preference code instead of id' do
      preference = build_stubbed(:preference)
      expect(preference.to_param).to eq(preference.code)
    end
  end

  describe '.with_choices' do
    it 'returns the preferences with choices' do
      preference = create(:preference, :with_choices)
      results = Preference.with_choices(preference.code)
      expect(results).to have_key(:preference_choices)
    end
  end
end
