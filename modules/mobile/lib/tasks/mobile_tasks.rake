# frozen_string_literal: true

namespace :mobile do
  desc 'Generate a JWT token for testing mobile API endpoints locally'
  task generate_token: :environment do
    require 'factory_bot_rails'
    include FactoryBot::Syntax::Methods

    # Parse command line arguments
    icn = ENV['icn'] || "1008596379V859838-#{SecureRandom.hex(4)}"
    first_name = ENV['first_name'] || 'Test'
    last_name = ENV['last_name'] || 'User'
    email = ENV['email'] || "test-#{SecureRandom.hex(4)}@example.com"
    duration = (ENV['duration'] || 30).to_i
    mhv_id = ENV['mhv_id'] # Optional MHV correlation ID

    puts "\n" + '=' * 80
    puts 'Mobile API Token Generator'
    puts '=' * 80

    # Ensure vamobile client config exists
    client_config = SignIn::ClientConfig.find_or_create_by(client_id: 'vamobile') do |config|
      config.authentication = SignIn::Constants::Auth::API
      config.anti_csrf = false
      config.pkce = true
      config.redirect_uri = 'vamobile://login-success'
      config.access_token_duration = SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES
      config.access_token_audience = 'vamobile'
      config.refresh_token_duration = SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS
      config.shared_sessions = true
      config.enforced_terms = SignIn::Constants::Auth::VA_TERMS
      config.terms_of_use_url = 'http://localhost:3001/terms-of-use'
    end

    puts "\n✓ Client config ready: #{client_config.client_id}"

    # Create user account
    user_account = UserAccount.find_or_create_by!(icn:)
    puts "✓ User account created/found: #{user_account.id}"

    # Create user verification
    user_verification = UserVerification.create!(
      user_account:,
      idme_uuid: SecureRandom.uuid,
      verified_at: Time.zone.now,
      locked: false
    )

    # Create user credential email
    UserCredentialEmail.create!(
      user_verification:,
      credential_email: email
    )
    puts "✓ User verification created"

    # Create OAuth session
    oauth_session = SignIn::OAuthSession.create!(
      handle: SecureRandom.uuid,
      user_account:,
      client_id: 'vamobile',
      hashed_refresh_token: SecureRandom.hex,
      refresh_expiration: Time.zone.now + 30.days,
      refresh_creation: Time.zone.now,
      user_verification:,
      credential_email: email,
      user_attributes: {
        first_name:,
        last_name:,
        email:,
        all_emails: [email]
      }.to_json
    )
    puts "✓ OAuth session created: #{oauth_session.handle}"

    # Cache MHV account if mhv_id is provided
    if mhv_id
      Rails.cache.write(
        "mhv_account_creation_#{icn}",
        {
          user_profile_id: mhv_id,
          premium: true,
          champ_va: true,
          patient: true,
          sm_account_created: true,
          message: 'Created by mobile:generate_token rake task'
        },
        expires_in: 1.year
      )
      puts "✓ MHV account cached with ID: #{mhv_id}"
    end

    # Create access token
    access_token = SignIn::AccessToken.new(
      session_handle: oauth_session.handle,
      client_id: 'vamobile',
      user_uuid: user_account.id,
      audience: ['vamobile'],
      refresh_token_hash: SecureRandom.hex,
      parent_refresh_token_hash: nil,
      anti_csrf_token: SecureRandom.hex,
      last_regeneration_time: Time.zone.now,
      version: SignIn::Constants::AccessToken::CURRENT_VERSION,
      expiration_time: Time.zone.now + duration.minutes,
      created_time: Time.zone.now,
      device_secret_hash: nil
    )
    puts "✓ Access token created"

    # Encode as JWT
    jwt_token = SignIn::AccessTokenJwtEncoder.new(access_token:).perform

    puts "\n" + '=' * 80
    puts 'SUCCESS! Token Generated'
    puts '=' * 80
    puts "\nUser Details:"
    puts "  ICN: #{icn}"
    puts "  Name: #{first_name} #{last_name}"
    puts "  Email: #{email}"
    puts "  User Account ID: #{user_account.id}"
    if mhv_id
      puts "  MHV ID: #{mhv_id} (cached for messaging access)"
    end
    puts "\nToken Details:"
    puts "  Expires: #{access_token.expiration_time}"
    puts "  Duration: #{duration} minutes"
    puts "\n" + '-' * 80
    puts 'JWT Token (copy this):'
    puts '-' * 80
    puts jwt_token
    puts '-' * 80

    puts "\nHow to use in Postman/curl:"
    puts "\n  GET http://localhost:3000/mobile/v0/user"
    puts "\n  Headers:"
    puts "    Authorization: Bearer #{jwt_token[0..50]}..."
    puts '    Authentication-Method: SIS'
    puts '    X-Key-Inflection: camel'

    puts "\n  curl example:"
    puts "    curl -H 'Authorization: Bearer #{jwt_token}' \\"
    puts "         -H 'Authentication-Method: SIS' \\"
    puts "         -H 'X-Key-Inflection: camel' \\"
    puts '         http://localhost:3000/mobile/v0/user'

    puts "\n" + '=' * 80
    puts 'Customize with environment variables:'
    puts '=' * 80
    puts '  rake mobile:generate_token icn=1234567890V123456 first_name=John last_name=Doe'
    puts '  rake mobile:generate_token email=custom@example.com duration=60'
    puts '  rake mobile:generate_token icn=1008596379V859838 mhv_id=12345678  # With MHV access'
    puts "\n"
  end

  desc 'Clean up test tokens and sessions'
  task cleanup_test_data: :environment do
    puts "\nCleaning up test data..."

    # Clean up OAuth sessions
    SignIn::OAuthSession.where(client_id: 'vamobile').destroy_all
    puts '✓ Removed OAuth sessions'

    # Clean up user accounts without verifications
    UserAccount.left_outer_joins(:user_verifications)
               .where(user_verifications: { id: nil })
               .destroy_all
    puts '✓ Removed orphaned user accounts'

    puts "✓ Cleanup complete\n"
  end

  desc 'Generate a token for a staging MHV user (requires MVI staging user data)'
  task generate_mhv_token: :environment do
    require 'factory_bot_rails'
    include FactoryBot::Syntax::Methods

    # Parse command line arguments
    user_number = ENV['user_number'] || '81'
    duration = (ENV['duration'] || 30).to_i
    custom_mhv_id = ENV['mhv_id'] # Optional: override the default MHV ID for the user

    # Map of common staging users (from mvi-staging-users.csv)
    staging_users = {
      '81' => {
        email: 'vets.gov.user+81@gmail.com',
        icn: '1008596379V859838',
        first_name: 'GREG',
        last_name: 'ANDERSON',
        mhv_correlation_id: '12345748'
      },
      '228' => {
        email: 'vets.gov.user+228@gmail.com',
        icn: '1012853893V362415',
        first_name: 'JOHN',
        last_name: 'SMITH',
        mhv_correlation_id: '12210827'
      },
      '36' => {
        email: 'vets.gov.user+36@gmail.com',
        icn: '1012666182V203559',
        first_name: 'WESLEY',
        last_name: 'FORD',
        mhv_correlation_id: '12345749'
      }
    }

    user_data = staging_users[user_number]

    unless user_data
      puts "\n❌ Unknown user number: #{user_number}"
      puts "\nAvailable users:"
      staging_users.each do |num, data|
        puts "  #{num}: #{data[:first_name]} #{data[:last_name]} (#{data[:email]})"
      end
      puts "\nUsage: rake mobile:generate_mhv_token user_number=81"
      puts "       rake mobile:generate_mhv_token user_number=81 mhv_id=YOUR_MHV_ID"
      exit 1
    end

    # Use custom MHV ID if provided, otherwise use default from user data
    mhv_id = custom_mhv_id || user_data[:mhv_correlation_id]

    puts "\n" + '=' * 80
    puts "Mobile API Token Generator - Staging MHV User"
    puts '=' * 80
    puts "\nGenerating token for staging user #{user_number}:"
    puts "  Email: #{user_data[:email]}"
    puts "  ICN: #{user_data[:icn]}"
    puts "  Name: #{user_data[:first_name]} #{user_data[:last_name]}"
    puts "  MHV Correlation ID: #{mhv_id}"
    puts "  (Custom MHV ID provided)" if custom_mhv_id

    # Ensure vamobile client config exists
    client_config = SignIn::ClientConfig.find_or_create_by(client_id: 'vamobile') do |config|
      config.authentication = SignIn::Constants::Auth::API
      config.anti_csrf = false
      config.pkce = true
      config.redirect_uri = 'vamobile://login-success'
      config.access_token_duration = SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES
      config.access_token_audience = 'vamobile'
      config.refresh_token_duration = SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS
      config.shared_sessions = true
      config.enforced_terms = SignIn::Constants::Auth::VA_TERMS
      config.terms_of_use_url = 'http://localhost:3001/terms-of-use'
    end

    puts "\n✓ Client config ready: #{client_config.client_id}"

    # Create or find user account with staging ICN
    user_account = UserAccount.find_or_create_by!(icn: user_data[:icn])
    puts "✓ User account created/found: #{user_account.id}"

    # Create user verification
    user_verification = UserVerification.create!(
      user_account:,
      idme_uuid: SecureRandom.uuid,
      verified_at: Time.zone.now,
      locked: false
    )

    # Create user credential email
    UserCredentialEmail.create!(
      user_verification:,
      credential_email: user_data[:email]
    )
    puts "✓ User verification created"

    # Create OAuth session
    oauth_session = SignIn::OAuthSession.create!(
      handle: SecureRandom.uuid,
      user_account:,
      client_id: 'vamobile',
      hashed_refresh_token: SecureRandom.hex,
      refresh_expiration: Time.zone.now + 30.days,
      refresh_creation: Time.zone.now,
      user_verification:,
      credential_email: user_data[:email],
      user_attributes: {
        first_name: user_data[:first_name],
        last_name: user_data[:last_name],
        email: user_data[:email],
        all_emails: [user_data[:email]]
      }.to_json
    )
    puts "✓ OAuth session created: #{oauth_session.handle}"

    # Cache MHV account for messaging access
    Rails.cache.write(
      "mhv_account_creation_#{user_data[:icn]}",
      {
        user_profile_id: mhv_id,
        premium: true,
        champ_va: true,
        patient: true,
        sm_account_created: true,
        message: 'Created by mobile:generate_mhv_token rake task'
      },
      expires_in: 1.year
    )
    puts "✓ MHV account cached with ID: #{mhv_id}"

    # Create access token
    access_token = SignIn::AccessToken.new(
      session_handle: oauth_session.handle,
      client_id: 'vamobile',
      user_uuid: user_account.id,
      audience: ['vamobile'],
      refresh_token_hash: SecureRandom.hex,
      parent_refresh_token_hash: nil,
      anti_csrf_token: SecureRandom.hex,
      last_regeneration_time: Time.zone.now,
      version: SignIn::Constants::AccessToken::CURRENT_VERSION,
      expiration_time: Time.zone.now + duration.minutes,
      created_time: Time.zone.now,
      device_secret_hash: nil
    )
    puts "✓ Access token created"

    # Encode as JWT
    jwt_token = SignIn::AccessTokenJwtEncoder.new(access_token:).perform

    puts "\n" + '=' * 80
    puts 'SUCCESS! Staging MHV User Token Generated'
    puts '=' * 80
    puts "\nStaging User Details:"
    puts "  User Number: #{user_number}"
    puts "  Email: #{user_data[:email]}"
    puts "  ICN: #{user_data[:icn]}"
    puts "  Name: #{user_data[:first_name]} #{user_data[:last_name]}"
    puts "  MHV Correlation ID: #{mhv_id}"
    puts "  (Custom MHV ID)" if custom_mhv_id
    puts "  User Account ID: #{user_account.id}"
    puts "\nToken Details:"
    puts "  Expires: #{access_token.expiration_time}"
    puts "  Duration: #{duration} minutes"
    puts "\n" + '-' * 80
    puts 'JWT Token (copy this):'
    puts '-' * 80
    puts jwt_token
    puts '-' * 80

    puts "\nHow to use with MHV staging data:"
    puts "\n  1. Make sure SOCKS proxy is running: vtk socks on"
    puts "  2. Make sure socat tunnels are running:"
    puts "     socat TCP-LISTEN:2003,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4428,socksport=2001"
    puts "  3. Make sure settings.local.yml is configured for MHV"
    puts "  4. Make sure dev cache is enabled: bin/rails dev:cache"
    puts "\n  Test Secure Messaging:"
    puts "    curl -H 'Authorization: Bearer #{jwt_token}' \\"
    puts "         -H 'Authentication-Method: SIS' \\"
    puts "         -H 'X-Key-Inflection: camel' \\"
    puts '         http://localhost:3000/mobile/v0/messaging/health/folders'

    puts "\n" + '=' * 80
    puts 'Other staging users:'
    puts '=' * 80
    staging_users.each do |num, data|
      puts "  rake mobile:generate_mhv_token user_number=#{num}  # #{data[:first_name]} #{data[:last_name]}"
    end
    puts "\n" + '=' * 80
    puts 'Use custom MHV ID:'
    puts '=' * 80
    puts "  rake mobile:generate_mhv_token user_number=81 mhv_id=YOUR_MHV_ID"
    puts "\n"
  end

  desc 'Import a staging bearer token and generate a new local token with the same user data'
  task import_staging_token: :environment do
    require 'jwt'
    require 'factory_bot_rails'
    include FactoryBot::Syntax::Methods

    # Get the staging token from environment variable
    staging_token = ENV['token']
    icn_param = ENV['icn'] # Required ICN from staging user
    mhv_id = ENV['mhv_id'] # Required for messaging access
    duration = (ENV['duration'] || 30).to_i

    unless staging_token
      puts "\n" + '=' * 80
      puts '❌ Error: No token provided'
      puts '=' * 80
      puts "\nUsage:"
      puts "  rake mobile:import_staging_token token='YOUR_STAGING_BEARER_TOKEN' icn=ICN_FROM_STAGING mhv_id=MHV_ID"
      puts "\nThis task will:"
      puts "  1. Decode your staging token (without verification)"
      puts "  2. Extract user information from the token"
      puts "  3. Create local user records with the provided ICN"
      puts "  4. Cache MHV account for messaging access"
      puts "  5. Generate a NEW local token (signed with local key)"
      puts "  6. You can then use the new local token with your local vets-api"
      puts "\nThe new token will represent the same user but work with local vets-api.\n"
      exit 1
    end

    unless icn_param
      puts "\n" + '=' * 80
      puts '❌ Error: ICN required'
      puts '=' * 80
      puts "\nYou must provide the ICN from the staging user:"
      puts "  rake mobile:import_staging_token token='YOUR_TOKEN' icn=STAGING_ICN mhv_id=YOUR_MHV_ID"
      puts "\nFind the ICN from staging data or by querying staging vets-api.\n"
      exit 1
    end

    unless mhv_id
      puts "\n" + '=' * 80
      puts '❌ Error: MHV ID required'
      puts '=' * 80
      puts "\nFor Secure Messaging access, you must provide the MHV correlation ID:"
      puts "  rake mobile:import_staging_token token='YOUR_TOKEN' icn=ICN mhv_id=YOUR_MHV_ID"
      puts "\nFind the MHV ID from staging data.\n"
      exit 1
    end

    puts "\n" + '=' * 80
    puts 'Importing Staging Bearer Token'
    puts '=' * 80

    # Decode token without verification to get payload
    begin
      decoded = JWT.decode(staging_token, nil, false)
      payload = decoded[0]
      puts "\n✓ Staging token decoded successfully"
    rescue JWT::DecodeError => e
      puts "\n❌ Error decoding token: #{e.message}"
      puts "Make sure you provided a valid JWT token"
      exit 1
    end

    puts "\nStaging Token Details:"
    puts "  Client ID: #{payload['client_id']}"
    puts "  Expires: #{Time.at(payload['exp'])}"
    user_attrs = payload['user_attributes'] || {}
    puts "  First Name: #{user_attrs['first_name']}" if user_attrs['first_name']
    puts "  Last Name: #{user_attrs['last_name']}" if user_attrs['last_name']
    puts "  Email: #{user_attrs['email']}" if user_attrs['email']

    # Extract user info
    first_name = user_attrs['first_name'] || 'Staging'
    last_name = user_attrs['last_name'] || 'User'
    email = user_attrs['email'] || "staging-#{SecureRandom.hex(4)}@example.com"
    # Use mock ICN for va_patient check in local development
    mock_icn = "1012853893V362415"
    puts "  Provided ICN: #{icn_param} (using mock ICN #{mock_icn} for local va_patient check)"
    icn = mock_icn

    puts "\nCreating local user with staging data..."

    # Ensure vamobile client config exists
    client_config = SignIn::ClientConfig.find_or_create_by(client_id: 'vamobile') do |config|
      config.authentication = SignIn::Constants::Auth::API
      config.anti_csrf = false
      config.pkce = true
      config.redirect_uri = 'vamobile://login-success'
      config.access_token_duration = SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES
      config.access_token_audience = 'vamobile'
      config.refresh_token_duration = SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS
      config.shared_sessions = true
      config.enforced_terms = SignIn::Constants::Auth::VA_TERMS
      config.terms_of_use_url = 'http://localhost:3001/terms-of-use'
    end
    puts "✓ Client config ready: #{client_config.client_id}"

    # Create user account
    user_account = UserAccount.create!(icn: icn)
    puts "✓ User account created: #{user_account.id}"

    # Create user verification
    user_verification = UserVerification.create!(
      user_account: user_account,
      idme_uuid: SecureRandom.uuid,
      verified_at: Time.zone.now,
      locked: false
    )

    # Create user credential email
    UserCredentialEmail.create!(
      user_verification: user_verification,
      credential_email: email
    )
    puts "✓ User verification created"

    # Create OAuth session
    oauth_session = SignIn::OAuthSession.create!(
      handle: SecureRandom.uuid,
      user_account: user_account,
      client_id: 'vamobile',
      hashed_refresh_token: SecureRandom.hex,
      refresh_expiration: Time.zone.now + 30.days,
      refresh_creation: Time.zone.now,
      user_verification: user_verification,
      credential_email: email,
      user_attributes: {
        first_name: first_name,
        last_name: last_name,
        email: email,
        all_emails: [email]
      }.to_json
    )
    puts "✓ OAuth session created: #{oauth_session.handle}"

    # Cache MHV account for messaging access
    Rails.cache.write(
      "mhv_account_creation_#{icn}",
      {
        user_profile_id: mhv_id,
        premium: true,
        champ_va: true,
        patient: true,
        sm_account_created: true,
        message: 'Created by mobile:import_staging_token rake task'
      },
      expires_in: 1.year
    )
    puts "✓ MHV account cached with ID: #{mhv_id}"

    # Create access token
    access_token = SignIn::AccessToken.new(
      session_handle: oauth_session.handle,
      client_id: 'vamobile',
      user_uuid: user_account.id,
      audience: ['vamobile'],
      refresh_token_hash: SecureRandom.hex,
      parent_refresh_token_hash: nil,
      anti_csrf_token: SecureRandom.hex,
      last_regeneration_time: Time.zone.now,
      version: SignIn::Constants::AccessToken::CURRENT_VERSION,
      expiration_time: Time.zone.now + duration.minutes,
      created_time: Time.zone.now,
      device_secret_hash: nil
    )
    puts "✓ Access token created"

    # Encode as JWT with LOCAL key
    jwt_token = SignIn::AccessTokenJwtEncoder.new(access_token: access_token).perform

    puts "\n" + '=' * 80
    puts 'SUCCESS! Local Token Generated from Staging User Data'
    puts '=' * 80
    puts "\nLocal User Details:"
    puts "  ICN: #{icn}"
    puts "  Name: #{first_name} #{last_name}"
    puts "  Email: #{email}"
    puts "  User Account ID: #{user_account.id}"
    puts "  MHV ID: #{mhv_id}"
    puts "\nToken Details:"
    puts "  Expires: #{access_token.expiration_time}"
    puts "  Duration: #{duration} minutes"
    puts "\nNext Steps:"
    puts "  1. Use the JWT token above for API requests"
    puts "  2. Run diagnostics: rake mobile:diagnose_messaging_access user_uuid=#{user_account.id}"
    puts "\n" + '-' * 80
    puts 'NEW Local JWT Token (copy this):'
    puts '-' * 80
    puts jwt_token
    puts '-' * 80

    puts "\nHow to use in Postman/curl:"
    puts "\n  Headers:"
    puts "    Authorization: Bearer #{jwt_token[0..50]}..."
    puts '    Authentication-Method: SIS'
    puts '    X-Key-Inflection: camel'

    puts "\n  curl example:"
    puts "    curl -H 'Authorization: Bearer #{jwt_token}' \\"
    puts "         -H 'Authentication-Method: SIS' \\"
    puts "         -H 'X-Key-Inflection: camel' \\"
    puts '         http://localhost:3000/mobile/v0/user'

    puts "\n✓ MHV account cached for Secure Messaging access"
    puts "  Make sure your socat tunnels are running to access MHV staging data"

    puts "\n" + '=' * 80
    puts 'Note: This is a NEW token signed with your local key.'
    puts 'The user data matches your staging token, but this token will work locally.'
    puts '=' * 80
    puts "\n"
  end

  desc 'Diagnose messaging access issues for a user'
  task diagnose_messaging_access: :environment do
    user_uuid = ENV['user_uuid']

    unless user_uuid
      puts "\n" + '=' * 80
      puts '❌ Error: No user UUID provided'
      puts '=' * 80
      puts "\nUsage:"
      puts "  rake mobile:diagnose_messaging_access user_uuid=YOUR_USER_UUID"
      puts "\nThis will check:"
      puts "  - User exists"
      puts "  - MHV correlation ID is present"
      puts "  - User is a VA patient"
      puts "  - MHV authentication succeeds"
      puts "  - Settings.local.yml configuration"
      puts "\n"
      exit 1
    end

    puts "\n" + '=' * 80
    puts 'Mobile Messaging Access Diagnostics'
    puts '=' * 80
    puts "\nChecking user: #{user_uuid}"

    # Check if user exists
    begin
      user = User.find(user_uuid)
      puts "\n✓ User found: #{user.uuid}"
    rescue => e
      puts "\n❌ User not found: #{e.message}"
      exit 1
    end

    # Check MHV correlation ID
    mhv_id = user.mhv_correlation_id
    if mhv_id
      puts "✓ MHV correlation ID: #{mhv_id}"
    else
      puts "❌ No MHV correlation ID found"
      puts "  User needs an MHV correlation ID to access Secure Messaging"
      exit 1
    end

    # Check VA patient status
    is_va_patient = user.va_patient?
    if is_va_patient
      puts "✓ User is a VA patient"
    else
      puts "❌ User is not a VA patient"
      puts "  Mobile messaging requires user.va_patient? to be true"
      exit 1
    end

    # Check settings
    puts "\nSettings Check:"
    puts "  SM Mock: #{Settings.mhv.sm.mock}"
    puts "  SM Host: #{Settings.mhv.api_gateway.hosts.sm_patient}"

    if Settings.mhv.sm.app_token.present?
      puts "  SM App Token: #{Settings.mhv.sm.app_token[0..10]}..."
    else
      puts "  ❌ SM App Token: NOT SET"
    end

    if Settings.mhv.sm.x_api_key.present?
      puts "  SM API Key: #{Settings.mhv.sm.x_api_key[0..10]}..."
    else
      puts "  ❌ SM API Key: NOT SET"
    end

    # Check if socat tunnel is running
    puts "\nTunnel Check:"
    if system('lsof -i :2003 > /dev/null 2>&1')
      puts "  ✓ Port 2003 (Secure Messaging) is listening"
    else
      puts "  ❌ Port 2003 is not listening"
      puts "     Start tunnel: socat TCP-LISTEN:2003,fork SOCKS5:localhost:fwdproxy-staging.vfs.va.gov:4428,socksport=2001"
    end

    # Try to create messaging client and authenticate
    puts "\nMHV Authentication Check:"
    begin
      client = Mobile::V0::Messaging::Client.new(session: {
        user_id: user.mhv_correlation_id,
        user_uuid: user.uuid
      })
      puts "  ✓ Client created"

      if client.session.expired?
        puts "  Session expired, attempting to authenticate..."
        client.authenticate
        puts "  ✓ Authentication successful!"
      else
        puts "  ✓ Session is valid (not expired)"
      end

      puts "\n" + '=' * 80
      puts '✓ All checks passed! User should have messaging access.'
      puts '=' * 80

    rescue => e
      puts "  ❌ Authentication failed: #{e.class}"
      puts "     Message: #{e.message}"
      puts "\n" + '=' * 80
      puts '❌ Messaging access will fail'
      puts '=' * 80
      puts "\nPossible issues:"
      puts "  1. MHV correlation ID doesn't exist in staging"
      puts "  2. MHV credentials (app_token, x_api_key) are incorrect"
      puts "  3. Socat tunnel to staging is not running"
      puts "  4. User doesn't have Secure Messaging enabled in staging MHV"
      puts "\nRecommended fix:"
      puts "  Use a real staging MHV ID that has Secure Messaging enabled:"
      puts "  rake mobile:generate_mhv_token user_number=81 mhv_id=REAL_STAGING_MHV_ID"
      puts "\n"
      exit 1
    end
  end
end
