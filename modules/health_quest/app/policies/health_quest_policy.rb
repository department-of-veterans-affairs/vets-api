# frozen_string_literal: true

HealthQuestPolicy = Struct.new(:user, :health_quest) do
  def access?
    Flipper.enabled?('show_healthcare_experience_questionnaire', user) && user.loa3?
  end
end
