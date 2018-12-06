# frozen_string_literal: true

require 'rails_helper'

describe UserPreference, type: :model do
  it 'has a valid factory' do
    user_preference = build(:user_preference)
    expect(user_preference).to be_valid
  end

  describe '.all_preferences_with_choices' do
    let(:user) { build(:user, :loa1) }

    before(:each) do
      allow_any_instance_of(User).to receive(:account).and_return(OpenStruct.new(id: 1))
    end

    context 'when the User has no UserPreferences' do
      it 'returns an empty array' do
        results = UserPreference.all_preferences_with_choices(1)
        expect(results).to eq []
      end
    end

    context 'when the User has a single Preference with UserPreferences' do
      it 'returns a single object in the array' do
        benefits = create(:preference, :benefits)
        UserPreference.create(account_id: 1,
                              preference_id: benefits.id,
                              preference_choice_id: benefits.choices.first.id)

        results = UserPreference.all_preferences_with_choices(1)

        expect(results.size).to eq 1
        expect(results.first).to have_key(:preference)
        expect(results.first).to have_key(:user_preferences)
      end
    end

    context 'when the User has multiple Preferences with UserPreferences' do
      it 'returns an array of objects including preference/user preference pairs' do
        benefits = create(:preference, :benefits)
        notifications = create(:preference, :notifications)
        UserPreference.create(account_id: 1,
                              preference_id: benefits.id,
                              preference_choice_id: benefits.choices.first.id)
        UserPreference.create(account_id: 1,
                              preference_id: notifications.id,
                              preference_choice_id: notifications.choices.first.id)
        UserPreference.create(account_id: 1,
                              preference_id: notifications.id,
                              preference_choice_id: notifications.choices.last.id)

        results = UserPreference.all_preferences_with_choices(1)

        expect(results.size).to eq 2
        results.each do |result|
          expect(result).to have_key(:preference)
          expect(result).to have_key(:user_preferences)
        end
      end
    end
  end
end
