# frozen_string_literal: true

require 'rails_helper'

describe UserPreference, type: :model do
  it 'has a valid factory' do
    user_preference = create(:user_preference)
    expect(user_preference).to be_valid
  end

  describe '.all_preferences_with_choices' do
    let(:user) { build(:user, :loa1) }
    let(:account) { create(:account) }
    let(:account_id) { account.id }

    before(:each) do
      allow_any_instance_of(User).to receive(:account).and_return(OpenStruct.new(id: account_id))
    end

    context 'when the User has no UserPreferences' do
      it 'returns an empty array' do
        results = UserPreference.all_preferences_with_choices(account_id)
        expect(results).to eq []
      end
    end

    context 'when the User has a single Preference with UserPreferences' do
      it 'returns a single object in the array' do
        benefits = create(:preference, :benefits)
        UserPreference.create(account: account,
                              preference_id: benefits.id,
                              preference_choice_id: benefits.choices.first.id)

        results = UserPreference.all_preferences_with_choices(account_id)

        expect(results.size).to eq 1
        expect(results.first).to have_key(:preference)
        expect(results.first).to have_key(:user_preferences)
      end
    end

    context 'when the User has multiple Preferences with UserPreferences' do
      it 'returns an array of objects including preference/user preference pairs' do
        benefits = create(:preference, :benefits)
        notifications = create(:preference, :notifications)
        UserPreference.create(account: account,
                              preference_id: benefits.id,
                              preference_choice_id: benefits.choices.first.id)
        UserPreference.create(account: account,
                              preference_id: notifications.id,
                              preference_choice_id: notifications.choices.first.id)
        UserPreference.create(account: account,
                              preference_id: notifications.id,
                              preference_choice_id: notifications.choices.last.id)

        results = UserPreference.all_preferences_with_choices(account_id)

        expect(results.size).to eq 2
        results.each do |result|
          expect(result).to have_key(:preference)
          expect(result).to have_key(:user_preferences)
        end
      end
    end
  end

  describe 'validations' do
    let(:john_account) { create :account }
    let(:mary_account) { create :account }
    let(:preference) { create :preference }
    let(:preference_choice) { create :preference_choice }
    let!(:user_preference) do
      create(
        :user_preference,
        account: john_account,
        preference: preference,
        preference_choice: preference_choice
      )
    end

    it 'can create a UserPreference with the same PreferenceChoice, for different users' do
      expect do
        create(
          :user_preference,
          account: mary_account,
          preference: preference,
          preference_choice: preference_choice
        )
      end.to change(UserPreference, :count).by(1)
    end

    it 'cannot create a UserPreference with the same PreferenceChoice, for the same user' do
      user_pref = build(
        :user_preference,
        account: john_account,
        preference: preference,
        preference_choice: preference_choice
      )

      expect { user_pref.save! }.to raise_error do |e|
        expect(e).to be_a(ActiveRecord::RecordInvalid)
        expect(e.message).to eq(
          'Validation failed: Account already has a UserPreference record with this PreferenceChoice'
        )
      end
    end
  end
end
