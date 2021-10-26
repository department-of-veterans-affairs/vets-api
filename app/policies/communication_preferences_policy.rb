# frozen_string_literal: true

CommunicationPreferencesPolicy = Struct.new(:user, :communication_preferences) do
  def access?
    Flipper.enabled?(:communication_preferences, user)
  end
end
