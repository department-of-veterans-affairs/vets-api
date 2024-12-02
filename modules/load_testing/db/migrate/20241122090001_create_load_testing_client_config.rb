class CreateLoadTestingClientConfig < ActiveRecord::Migration[7.1]
  def up
    return if Rails.env.test?

    # First remove any existing config
    SignIn::ClientConfig.where(client_id: 'vaweb_api_load_testing').destroy_all

    # Create new config matching ticket requirements
    SignIn::ClientConfig.create!(
      client_id: 'vaweb_api_load_testing',
      authentication: 'api',
      anti_csrf: true,
      redirect_uri: 'http://localhost:3000/load_testing/callback',
      access_token_duration: 'PT30M',
      refresh_token_duration: 'P45D',
      description: 'Load Testing Client',
      pkce: true,
      shared_sessions: false,
      service_levels: ['min', 'loa1', 'loa3', 'ial1', 'ial2'],
      access_token_audience: 'vaweb_api_load_testing',
      access_token_attributes: ['email'],
      credential_service_providers: ['logingov', 'idme', 'dslogon', 'mhv']
    )
  end

  def down
    return if Rails.env.test?
    SignIn::ClientConfig.where(client_id: 'vaweb_api_load_testing').destroy_all
  end
end 