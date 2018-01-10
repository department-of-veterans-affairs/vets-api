# frozen_string_literal: true
module BetaSwitch
  def beta_enabled?(uuid, feature_name)
    BetaRegistration.where(user_uuid: uuid, feature: feature_name).count > 0
  end
end
