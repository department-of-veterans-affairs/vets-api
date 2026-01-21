# frozen_string_literal: true

module FeatureFlagHelper
  extend ActiveSupport::Concern

  def verify_feature_flag!(flag, user = @current_user, error_message: nil)
    return if Flipper.enabled?(flag, user)

    message = error_message || "Travel Pay #{flag} is disabled for user"
    Rails.logger.error(message:)
    raise Common::Exceptions::ServiceUnavailable.new(detail: message)
  end
end
