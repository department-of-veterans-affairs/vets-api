# frozen_string_literal: true

require 'evss/ppiu/service'

PPIUPolicy = Struct.new(:user, :ppiu) do
  def allowed_providers
    %w[
      idme
      oauth_IDME
      logingov
      oauth_LOGINGOV
    ].freeze
  end

  def access?
    raise_error if reject?
    user.loa3? &&
      allowed_providers.include?(user.identity.sign_in[:service_name])
  end

  def access_update?
    raise_error if reject?

    res = EVSS::PPIU::Service.new(user).get_payment_information

    res.responses.first.control_information.authorized?
  end

  def reject?
    Flipper.enabled?(:profile_ppiu_reject_requests, user)
  end

  def raise_error
    message = 'The EVSS PPIU endpoint will be decommissioned. Access is blocked.'
    raise Common::Exceptions::Forbidden.new(detail: message, source: 'PPIU Policy')
  end
end
