# frozen_string_literal: true

SignInService::Sts.configure do |config|
  config.base_url = Settings.sign_in.sts_client.base_url
end
