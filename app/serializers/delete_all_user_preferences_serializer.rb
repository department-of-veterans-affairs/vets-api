# frozen_string_literal: true

class DeleteAllUserPreferencesSerializer < ActiveModel::Serializer
  attributes :preference_code, :user_preferences

  def id
    nil
  end

  def preference_code
    object[:code]
  end

  def user_preferences
    []
  end
end
