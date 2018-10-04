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
end
