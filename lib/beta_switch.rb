# frozen_string_literal: true

module BetaSwitch
  def beta_enabled?(uuid, feature_name)
    BetaRegistration.find_by(user_uuid: uuid, feature: feature_name).present?
  end
end
