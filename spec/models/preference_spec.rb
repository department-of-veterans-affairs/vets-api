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

  describe '.cached!' do
    let(:preference) { create(:preference) }

    it 'first attempts to fetch the Preference record from the Redis cache' do
      expect(Preference).to receive(:do_cached_with)
      Preference.cached? preference
      pending
    end

    it 'returns the db Preference record', :aggregate_failures do
      pending
    end
  end
end
