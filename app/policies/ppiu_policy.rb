# frozen_string_literal: true

require 'evss/ppiu/service'

PPIUPolicy = Struct.new(:user, :ppiu) do
  def allowed_providers
    %w[
      idme
      oauth_IDME
      logingov
    ].freeze
  end

  def access?
    user.loa3? &&
      allowed_providers.include?(user.identity.sign_in[:service_name]) &&
      Flipper.enabled?(:direct_deposit_cnp, user)
  end

  def access_update?
    res = EVSS::PPIU::Service.new(user).get_payment_information

    res.responses.first.control_information.authorized?
  end
end
