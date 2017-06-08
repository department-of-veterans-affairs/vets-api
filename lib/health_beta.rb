# frozen_string_literal: true
module HealthBeta
  def beta_enabled?(uuid)
    HealthBetaRegistration.find_by(user_uuid: uuid).present?
  end
end
