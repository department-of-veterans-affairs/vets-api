# frozen_string_literal: true

module UserPreferences
  class Validator
    attr_reader :requested_user_preferences

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
    def initialize(requested_user_preferences)
      @requested_user_preferences = requested_user_preferences
    end

    # Validates the initialized requested_user_preferences for the presence
    # of all of the required attributes.
    #
    # Raises a Common::Exceptions::ParameterMissing should any validation not succeed.
    #
    # @return [Array<Hash>] On success, returns the original requested_user_preferences
    # @return [Common::Exceptions::ParameterMissing] On failure, raises an exception
    #
    def of_presence!
      requested_user_preferences.each do |requested|
        validate_pref_code!(requested)
        validate_user_pref_key!(requested)

        requested.dig('user_preferences').each do |user_preference|
          validate_user_pref!(user_preference)
          validate_user_pref_code!(user_preference)
        end
      end

      requested_user_preferences
    end

    private

    def validate_pref_code!(requested)
      code = requested.dig 'preference', 'code'

      raise_missing_parameter!('preference#code') if code.blank?
    end

    def validate_user_pref_key!(requested)
      raise_missing_parameter!('user_preferences') if requested.dig('user_preferences').blank?
    end

    def validate_user_pref!(user_preference)
      raise_missing_parameter!('user_preferences') if user_preference.blank?
    end

    def validate_user_pref_code!(user_preference)
      raise_missing_parameter!('user_preference#code') if user_preference['code'].blank?
    end

    def raise_missing_parameter!(parameter)
      raise Common::Exceptions::ParameterMissing.new(parameter), parameter
    end
  end
end
