# frozen_string_literal: true

class UserPreferenceSerializer < ActiveModel::Serializer
  attributes :user_preferences

  def id
    nil
  end

  # Object is an array of `Preference` and `PreferenceChoice` pairings.
  # For example:
  #   [
  #     {
  #       preference: Preference,
  #       user_preferences: [PreferenceChoice, PreferenceChoice]
  #     },
  #     ...
  #   ]
  #
  def user_preferences
    object.map do |pair|
      {
        code: pair[:preference].code,
        title: pair[:preference].title,
        user_preferences: pair[:user_preferences].map { |pref| { code: pref.code, description: pref.description } }
      }
    end
  end
end
