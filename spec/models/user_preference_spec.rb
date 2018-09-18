# frozen_string_literal: true

require 'rails_helper'

describe UserPreference, type: :model do
  it 'has a valid factory' do
    user_preference = build(:user_preference)
    expect(user_preference).to be_valid
  end
end
