# frozen_string_literal: true

class TokenUtil
  def self.validate_token(token)
    raise error_klass('Invalid audience') unless TokenUtil.valid_audience?(token)

    # Only static tokens utilize this validator at this time
    token.static?
  end

  # Validates the token audience against the service caller supplied `aud` payload.
  # If none, it validates against the configured default.
  def self.valid_audience?(token)
    if token.aud.nil?
      token.payload['aud'] == Settings.oidc.isolated_audience.default
    else
      # Temorarily accept the default audience or the API specificed audience
      [Settings.oidc.isolated_audience.default, *token.aud].include?(token.payload['aud'])
    end
  end

  def self.error_klass(error_detail_string)
    # Errors from the jwt gem (and other dependencies) are reraised with
    # this class so we can exclude them from Sentry without needing to know
    # all the classes used by our dependencies.
    Common::Exceptions::TokenValidationError.new(detail: error_detail_string)
  end
end
