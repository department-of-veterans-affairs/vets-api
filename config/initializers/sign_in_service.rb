# frozen_string_literal: true

SignInService::Sts.configure do |config|
  config.base_url = IdentitySettings.sign_in.sts_client.base_url
end
