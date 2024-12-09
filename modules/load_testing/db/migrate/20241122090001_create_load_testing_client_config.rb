class CreateLoadTestingClientConfig < ActiveRecord::Migration[7.1]
  def up
    # Skip in test environment
    return if Rails.env.test?

    SignIn::ClientConfig.find_or_create_by!(client_id: 'load_test_client') do |config|
      config.authentication = 'api'
      config.anti_csrf = true
      config.redirect_uri = 'http://localhost:3000/v0/sign_in/callback'
      config.access_token_duration = 'PT30M'
      config.refresh_token_duration = 'P45D'
      config.description = 'Load Testing Client'
      config.pkce = true
      config.shared_sessions = false
      config.service_levels = ['min', 'loa1', 'loa3', 'ial1', 'ial2']
      config.access_token_audience = 'load_test_client'
      config.access_token_attributes = ['email']
      config.credential_service_providers = ['logingov']
      config.oauth_settings = {
        'logingov' => {
          'client_id' => 'load_test_client',
          'client_secret' => 'test_secret',
          'authorization_endpoint' => 'https://idp.int.identitysandbox.gov/openid_connect/authorize',
          'token_endpoint' => 'https://idp.int.identitysandbox.gov/api/openid_connect/token',
          'userinfo_endpoint' => 'https://idp.int.identitysandbox.gov/api/openid_connect/userinfo'
        }
      }
    end
  end

  def down
    # Skip in test environment
    return if Rails.env.test?

    SignIn::ClientConfig.find_by(client_id: 'load_test_client')&.destroy
  end
end 