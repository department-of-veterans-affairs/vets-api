# frozen_string_literal: true

HealthQuestPolicy = Struct.new(:user, :health_quest) do
  def access?
    Flipper.enabled?('va_online_scheduling', user) && user.loa3?
  end
end
