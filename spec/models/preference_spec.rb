# frozen_string_literal: true

require 'rails_helper'

describe Preference do
  it 'has a valid factory' do
    preference = build(:preference)
    expect(preference).to be_valid
  end
end
