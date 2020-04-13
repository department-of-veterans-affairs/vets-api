# frozen_string_literal: true

# This class handles both the creating and updating of a user's UserPreferences.
# It takes care of updating because, for each request, we are deleting all
# of the user's associated UserPreference records, and creating new ones.

# Also note that it accepts and sets multiple preference/choices combinations in
# each request.  This is so that the end user can make a number of preference decisions
# in one page, and the FE can send over just one request, in order to create all of the
# UserPreference records for all of the users decisions.
#
# This class is responsible for:
#   - accepting an Account record and an array of preference/choice pairings
#   - destroying any associated existing UserPreference records
#   - creating new UserPreference records based on the request
#   - returning the successfully created pairings that were requested
#
module UserPreferences
  class Grantor
    attr_reader :account, :requested_user_preferences, :preference_codes, :user_preferences,
                :preference, :preference_choice, :preference_records, :preference_choice_records

    # @param account [Account] An instance of Account
    # @param requested_user_preferences [Array<Hash>] An array of hashes. Each hash contains
    #   a Preference#code, and the associates PreferenceChoice#codes the user selected.
    #   For example:
    #   [
    #     {
    #       preference: { code: 'benefits' },
    #       user_preferences: [
    #         { code: 'health-care' },
    #         ...
    #       ]
    #     },
    #     ...
    #   ]
    #
    def initialize(account, requested_user_preferences)
      @account = account
      @requested_user_preferences = Validator.new(requested_user_preferences).of_presence!
      @preference_codes = derive_preference_codes
      @preference_records = eager_load_preferences
      @preference_choice_records = eager_load_preference_choices
    end

    # @return [Array<Hash>] An array of hashes. Each hash contains the db Preference and
    #   PreferenceChoice records that are associated with the user's newly created
    #   UserPreference records.  For example:
    #   [
    #     {
    #       preference: <Preference>,
    #       user_preferences: [
    #         <PreferenceChoice>,
    #         <PreferenceChoice>,
    #         ...
    #       ]
    #     },
    #     ...
    #   ]
    #
    def execute!
      destroy_user_preferences!

      requested_user_preferences.map do |preferences|
        assign_preference_codes(preferences)

        results = {
          preference: preference,
          user_preferences: []
        }

        user_preferences.each do |user_preference|
          assign_user_preference_codes(user_preference)
          create_user_preference!
          add_choice_to(results)
        end

        results
      end
    end

    private

    def derive_preference_codes
      requested_user_preferences.map { |requested| requested.dig 'preference', 'code' }
    end

    def eager_load_preferences
      Preference.where(code: preference_codes).to_a
    end

    def eager_load_preference_choices
      PreferenceChoice.where(code: derive_preference_choice_codes).to_a
    end

    def derive_preference_choice_codes
      requested_user_preferences.map do |requested|
        requested.dig('user_preferences').map do |user_preference|
          user_preference['code']
        end
      end.flatten
    end

    # rubocop:disable Layout/LineLength
    def destroy_user_preferences!
      UserPreference.for_preference_and_account(account.id, preference_codes).each(&:destroy!)
    rescue ActiveRecord::RecordNotDestroyed => e
      raise Common::Exceptions::UnprocessableEntity.new(
        detail: "When destroying UserPreference records for Account #{account.id} with Preference codes '#{preference_codes}', experienced ActiveRecord::RecordNotDestroyed with this error: #{e}"
      )
    end
    # rubocop:enable Layout/LineLength

    def assign_preference_codes(preferences)
      preference_code   = preferences.dig 'preference', 'code'
      @user_preferences = preferences.dig 'user_preferences'
      @preference       = find_record(preference_records, preference_code)

      raise Common::Exceptions::RecordNotFound, preference_code if preference.blank?
    end

    def assign_user_preference_codes(user_preference)
      choice_code        = user_preference.dig 'code'
      @preference_choice = find_record(preference_choice_records, choice_code)

      raise Common::Exceptions::RecordNotFound, choice_code if preference_choice.blank?
    end

    def find_record(records, code)
      records.find { |record| record.code == code }
    end

    def create_user_preference!
      UserPreference.create!(
        account_id: account.id,
        preference_id: preference.id,
        preference_choice_id: preference_choice.id
      )
    end

    def add_choice_to(results)
      results[:user_preferences] << preference_choice
    end
  end
end
