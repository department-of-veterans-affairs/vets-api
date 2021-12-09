# frozen_string_literal: true

Ch33DdPolicy = Struct.new(:user, :ch33_dd) do
  def allowed_providers
    %w[
      idme
      logingov
    ].freeze
  end

  def access?
    user.loa3? && allowed_providers.include?(user.identity.sign_in[:service_name]) && Flipper.enabled?(
      :direct_deposit_edu, user
    )
  end
end
