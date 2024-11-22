class CreateLoadTestingClientConfig < ActiveRecord::Migration[7.1]
  def up
    # Skip in test environment
    return if Rails.env.test?

    # Create test client config
    client_config = SignIn::ClientConfig.new(
      client_id: 'load_test_client',
      authentication: 'api',
      anti_csrf: true,
      redirect_uri: 'http://localhost:3000/load_testing/callback',
      access_token_duration: 'PT30M',  # ISO 8601 duration format: 30 minutes
      access_token_audience: 'load_testing',
      refresh_token_duration: 'PT30M',  # ISO 8601 duration format: 30 minutes
      logout_redirect_uri: 'http://localhost:3000/load_testing/logout',
      pkce: true,
      certificates: nil,
      description: 'Load Testing Client',
      access_token_attributes: ['email'],
      terms_of_use_url: nil,
      enforced_terms: nil,
      shared_sessions: false,
      service_levels: ['ial2'],
      credential_service_providers: ['logingov']
    )

    # Log validation errors if any
    unless client_config.valid?
      puts "Validation errors: #{client_config.errors.full_messages}"
      puts "Attributes: #{client_config.attributes.inspect}"
      puts "Service Levels: #{client_config.service_levels.inspect}"
      puts "Credential Service Providers: #{client_config.credential_service_providers.inspect}"
      puts "Access Token Attributes: #{client_config.access_token_attributes.inspect}"
      puts "Access Token Duration: #{client_config.access_token_duration.inspect}"
      puts "Refresh Token Duration: #{client_config.refresh_token_duration.inspect}"
    end

    # Save with bang to raise error if validation fails
    client_config.save!
  rescue ActiveRecord::RecordInvalid => e
    puts "Validation errors: #{e.record.errors.full_messages}"
    puts "Attributes: #{e.record.attributes.inspect}"
    puts "Service Levels: #{e.record.service_levels.inspect}"
    puts "Credential Service Providers: #{e.record.credential_service_providers.inspect}"
    puts "Access Token Attributes: #{e.record.access_token_attributes.inspect}"
    puts "Access Token Duration: #{e.record.access_token_duration.inspect}"
    puts "Refresh Token Duration: #{e.record.refresh_token_duration.inspect}"
    raise e
  end

  def down
    # Skip in test environment
    return if Rails.env.test?

    SignIn::ClientConfig.find_by(client_id: 'load_test_client')&.destroy
  end
end 