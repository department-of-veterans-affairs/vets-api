# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Layout/LineLength
RSpec.describe UserPreferences::Grantor do
  let(:user) { build(:user, :accountable) }
  let(:account) { user.account }
  let(:preference_1) { create :preference }
  let(:preference_2) { create :preference }
  let(:choice_1) { create :preference_choice, preference: preference_1 }
  let(:choice_2) { create :preference_choice, preference: preference_1 }
  let(:choice_3) { create :preference_choice, preference: preference_2 }
  let(:choice_4) { create :preference_choice, preference: preference_2 }
  let(:requested_user_preferences) do
    [
      {
        preference: {
          code: preference_1.code
        },
        user_preferences: [
          { code: choice_1.code },
          { code: choice_2.code }
        ]
      },
      {
        preference: {
          code: preference_2.code
        },
        user_preferences: [
          { code: choice_3.code },
          { code: choice_4.code }
        ]
      }
    ].as_json
  end

  describe 'execute!' do
    context 'when the User does *not* already have UserPreference records for the Preference' do
      let(:set_user_preferences) { UserPreferences::Grantor.new(account, requested_user_preferences) }

      it 'creates UserPreference records' do
        expect do
          set_user_preferences.execute!
        end.to change(UserPreference, :count).by(4)
      end

      it 'creates UserPreference records for the passed user Account' do
        set_user_preferences.execute!

        expect(user.account.user_preferences.count).to eq 4
      end

      it 'creates UserPreference records for the passed Preferences', :aggregate_failures do
        set_user_preferences.execute!

        expect(UserPreference.where(preference_id: preference_1.id).count).to eq 2
        expect(UserPreference.where(preference_id: preference_2.id).count).to eq 2
      end

      it 'returns the Preference and PreferenceChoices that were associated in the new UserPreferences', :aggregate_failures do
        response = set_user_preferences.execute!

        returned_codes1 = returned_user_preference_codes_in(response, preference_1)
        returned_codes2 = returned_user_preference_codes_in(response, preference_2)

        expect(returned_codes1).to match_array [choice_1.code, choice_2.code]
        expect(returned_codes2).to match_array [choice_3.code, choice_4.code]
      end
    end

    context 'when the User already has UserPreference records for the Preference' do
      let!(:user_preference_1) { create_user_preference(preference_1, choice_1) }
      let!(:user_preference_2) { create_user_preference(preference_1, choice_2) }
      let!(:user_preference_3) { create_user_preference(preference_2, choice_3) }
      let!(:user_preference_4) { create_user_preference(preference_2, choice_4) }
      let!(:existing_user_preference_ids) { user.account.user_preferences.pluck(:id) }
      let(:choice_5) { create :preference_choice, preference: preference_1 }
      let(:choice_6) { create :preference_choice, preference: preference_1 }
      let(:choice_7) { create :preference_choice, preference: preference_2 }
      let(:choice_8) { create :preference_choice, preference: preference_2 }
      let(:requested_user_preferences) do
        [
          {
            preference: {
              code: preference_1.code
            },
            user_preferences: [
              { code: choice_5.code },
              { code: choice_6.code }
            ]
          },
          {
            preference: {
              code: preference_2.code
            },
            user_preferences: [
              { code: choice_7.code },
              { code: choice_8.code }
            ]
          }
        ].as_json
      end
      let(:set_user_preferences) { UserPreferences::Grantor.new(account, requested_user_preferences) }

      before { expect(user.account.user_preferences.count).to eq 4 }

      it "deletes the user's existing records for the associated Preference and creates new ones", :aggregate_failures do
        set_user_preferences.execute!

        existing_user_preference_ids.each do |user_preference_id|
          expect(UserPreference.find_by(id: user_preference_id)).to be_nil
        end
      end

      it 'creates new UserPreference records', :aggregate_failures do
        set_user_preferences.execute!

        expect(user.account.user_preferences.count).to eq 4
        expect(existing_user_preference_ids).not_to match_array UserPreference.pluck(:id)
      end

      it 'returns the Preference and PreferenceChoices that were associated in the new UserPreferences', :aggregate_failures do
        response = set_user_preferences.execute!

        returned_codes1 = returned_user_preference_codes_in(response, preference_1)
        returned_codes2 = returned_user_preference_codes_in(response, preference_2)

        expect(returned_codes1).to match_array [choice_5.code, choice_6.code]
        expect(returned_codes2).to match_array [choice_7.code, choice_8.code]
      end

      context 'when the user has other non-related UserPreferences in place' do
        let(:some_preference) { create(:preference) }
        let(:some_choice) { create(:preference_choice) }
        let!(:other_user_preference) { create_user_preference(some_preference, some_choice) }

        before do
          expect(user.account.user_preferences.count).to eq 5
          expect(user.account.user_preferences).to include other_user_preference
        end

        it 'does not delete UserPreference records that are not associated with the passed Preferences' do
          set_user_preferences.execute!

          expect(user.account.user_preferences).to include other_user_preference
        end
      end
    end

    context 'when a passed Preference#code is not in the db' do
      let(:non_existant_code) { 'code-that-does-not-exist' }
      let(:bad_request_body) do
        [
          {
            preference: { code: non_existant_code },
            user_preferences: [{ code: choice_1.code }]
          }
        ].as_json
      end
      let(:set_user_preferences) { UserPreferences::Grantor.new(account, bad_request_body) }

      it 'returns a 404 not found', :aggregate_failures do
        expect { set_user_preferences.execute! }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::RecordNotFound)
          expect(error.status_code).to eq(404)
          expect(error.message).to eq('Record not found')
          expect(
            error.errors.first.detail
          ).to eq "The record identified by #{non_existant_code} could not be found"
        end
      end
    end

    context 'when a passed PreferenceChoice#code is not in the db' do
      let(:non_existant_code) { 'code-that-does-not-exist' }
      let(:bad_request_body) do
        [
          {
            preference: { code: preference_1.code },
            user_preferences: [{ code: non_existant_code }]
          }
        ].as_json
      end
      let(:set_user_preferences) { UserPreferences::Grantor.new(account, bad_request_body) }

      it 'returns a 404 not found', :aggregate_failures do
        expect { set_user_preferences.execute! }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::RecordNotFound)
          expect(error.status_code).to eq(404)
          expect(error.message).to eq('Record not found')
          expect(
            error.errors.first.detail
          ).to eq "The record identified by #{non_existant_code} could not be found"
        end
      end
    end

    context 'with problems trying to destroy the existing UserPreference records' do
      let(:set_user_preferences) { UserPreferences::Grantor.new(account, requested_user_preferences) }

      it 'raises an exception' do
        allow(UserPreference).to receive(:for_preference_and_account).and_raise(
          ActiveRecord::RecordNotDestroyed.new('Cannot destroy this record')
        )

        expect { set_user_preferences.execute! }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::UnprocessableEntity)
          expect(error.status_code).to eq(422)
          expect(error.errors.first.detail).to include 'ActiveRecord::RecordNotDestroyed'
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength

def returned_user_preference_codes_in(response, preference)
  pairings = response.select { |pair| pair[:preference].code == preference.code }

  pairings.first.dig(:user_preferences).map(&:code)
end

def create_user_preference(preference, preference_choice)
  create(
    :user_preference,
    account: user.account,
    preference: preference,
    preference_choice: preference_choice
  )
end
