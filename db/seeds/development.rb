# frozen_string_literal: true

require 'sign_in/constants/auth'

# Create Config for va.gov Sign in Service client
vaweb = SignIn::ClientConfig.find_or_initialize_by(client_id: 'vaweb')
vaweb.update!(authentication: SignIn::Constants::Auth::COOKIE,
              anti_csrf: true,
              redirect_uri: 'http://localhost:3001/auth/login/callback',
              access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
              access_token_audience: 'va.gov',
              pkce: true,
              logout_redirect_uri: 'http://localhost:3001',
              enforced_terms: SignIn::Constants::Auth::VA_TERMS,
              terms_of_use_url: 'http://localhost:3001/terms-of-use',
              shared_sessions: true,
              refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Config for VA flagship mobile Sign in Service client
vamobile = SignIn::ClientConfig.find_or_initialize_by(client_id: 'vamobile')
vamobile.update!(authentication: SignIn::Constants::Auth::API,
                 anti_csrf: false,
                 redirect_uri: 'vamobile://login-success',
                 pkce: true,
                 access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES,
                 access_token_audience: 'vamobile',
                 shared_sessions: true,
                 enforced_terms: SignIn::Constants::Auth::VA_TERMS,
                 terms_of_use_url: 'http://localhost:3001/terms-of-use',
                 refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS)

# Create Config for localhost mocked authentication client
vamobile_mock = SignIn::ClientConfig.find_or_initialize_by(client_id: 'vamobile_test')
vamobile_mock.update!(authentication: SignIn::Constants::Auth::API,
                      anti_csrf: false,
                      redirect_uri: 'http://localhost:4001/auth/sis/login-success',
                      pkce: true,
                      access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES,
                      access_token_audience: 'vamobile',
                      refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS)

vaokta = SignIn::ClientConfig.find_or_initialize_by(client_id: 'okta_test')
vaokta.update!(authentication: SignIn::Constants::Auth::API,
               anti_csrf: false,
               redirect_uri: 'http://localhost:3002/auth/callback',
               access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
               access_token_audience: 'okta',
               pkce: true,
               logout_redirect_uri: 'http://localhost:3001',
               enforced_terms: SignIn::Constants::Auth::VA_TERMS,
               terms_of_use_url: 'http://localhost:3001/terms-of-use',
               shared_sessions: true,
               json_api_compatibility: false,
               refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Config for localhost mocked authentication client
vamock = SignIn::ClientConfig.find_or_initialize_by(client_id: 'vamock')
vamock.update!(authentication: SignIn::Constants::Auth::MOCK,
               anti_csrf: true,
               pkce: true,
               redirect_uri: 'http://localhost:3001/auth/login/callback',
               access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
               access_token_audience: 'va.gov',
               logout_redirect_uri: 'http://localhost:3001',
               shared_sessions: true,
               refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Config for example external client using cookie auth
sample_client_web = SignIn::ClientConfig.find_or_initialize_by(client_id: 'sample_client_web')
sample_client_web.update!(authentication: SignIn::Constants::Auth::COOKIE,
                          anti_csrf: true,
                          pkce: true,
                          redirect_uri: 'http://localhost:4567/auth/result',
                          access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
                          access_token_audience: 'sample_client',
                          logout_redirect_uri: 'http://localhost:4567',
                          shared_sessions: true,
                          refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Config for example external client using api auth
sample_client_api = SignIn::ClientConfig.find_or_initialize_by(client_id: 'sample_client_api')
sample_client_api.update!(authentication: SignIn::Constants::Auth::API,
                          anti_csrf: false,
                          pkce: true,
                          redirect_uri: 'http://localhost:4567/auth/result',
                          access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
                          access_token_audience: 'sample_client',
                          logout_redirect_uri: 'http://localhost:4567',
                          refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Config for example sts service account
sample_sts_config = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: 'sample_sts_service_account')
sample_sts_config.update!(
  description: 'Sample STS Service Account',
  scopes: [],
  access_token_audience: 'http://localhost:3000',
  access_token_user_attributes: [],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certificates: [File.read('spec/fixtures/sign_in/sts_client.crt')]
)

# Create Config for VA Identity Dashboard using cookie auth
vaid_dash = SignIn::ClientConfig.find_or_initialize_by(client_id: 'identity_dashboard_rails')
vaid_dash.update!(authentication: SignIn::Constants::Auth::COOKIE,
                  anti_csrf: true,
                  pkce: true,
                  redirect_uri: 'http://localhost:4000/sessions/callback',
                  access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
                  access_token_audience: 'identity dashboard',
                  access_token_attributes: %w[first_name last_name email],
                  logout_redirect_uri: 'http://localhost:4000/sessions/logout_callback',
                  refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Service Account Config for VA Identity Dashboard Service Account auth
vaid_certificate = File.read('spec/fixtures/sign_in/identity_dashboard_service_account.crt')
vaid_service_account_id = '01b8ebaac5215f84640ade756b645f28'
vaid_access_token_duration = SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES
identity_dashboard_service_account_config =
  SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: vaid_service_account_id)
identity_dashboard_service_account_config.update!(service_account_id: vaid_service_account_id,
                                                  description: 'VA Identity Dashboard API',
                                                  scopes: [
                                                    'http://localhost:3000/sign_in/client_configs',
                                                    'http://localhost:3000/sign_in/service_account_configs'
                                                  ],
                                                  access_token_audience: 'http://localhost:4000',
                                                  access_token_duration: vaid_access_token_duration,
                                                  certificates: [vaid_certificate],
                                                  access_token_user_attributes: %w[icn type credential_id])

# Create Service Account Config for Chatbot
chatbot = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: '03f8a6cf626527942e45348f3e40b2ad')
chatbot.update!(
  description: 'Chatbot User Auth',
  scopes: ['http://localhost:3000/v0/virtual_agent/user'],
  access_token_audience: 'http://localhost:3978/api/messages',
  access_token_user_attributes: [],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certificates: [File.read('spec/fixtures/sign_in/sts_client.crt')]
)

# Create Service Account Config for Chatbot
chatbot = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: '88a6d94a3182fd63279ea5565f26bcb4')
chatbot.update!(
  description: 'Chatbot',
  scopes: ['http://localhost:3000/v0/map_services/chatbot/token', 'http://localhost:3000/v0/virtual_agent/claims'],
  access_token_audience: 'http://localhost:3978/api/messages',
  access_token_user_attributes: ['icn'],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certificates: [File.read('spec/fixtures/sign_in/sts_client.crt')]
)

# Create config for accredited_representative_portal
arp = SignIn::ClientConfig.find_or_initialize_by(client_id: 'arp')
arp.update!(authentication: SignIn::Constants::Auth::COOKIE,
            anti_csrf: true,
            pkce: true,
            description: 'Accredited Representative Portal',
            redirect_uri: 'http://localhost:3001/auth/login/callback',
            access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
            access_token_attributes: %w[first_name last_name email],
            refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES,
            logout_redirect_uri: 'http://localhost:3001/representative',
            credential_service_providers: [SignIn::Constants::Auth::IDME, SignIn::Constants::Auth::LOGINGOV],
            service_levels: [SignIn::Constants::Auth::LOA3, SignIn::Constants::Auth::IAL2])

# Create Service Account Config for BTSSS
btsss = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: 'bbb5830ecebdef04556e9c430e374972')
btsss.update!(
  description: 'BTSSS',
  scopes: [],
  access_token_audience: 'http://localhost:3000',
  access_token_user_attributes: ['icn'],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certificates: [File.read('spec/fixtures/sign_in/sts_client.crt')]
)

# Create Service Account Config for IVC_Champva
btsss = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: '6747fb5e6bdb18b2f6f0b890ff584b07')
btsss.update!(
  description: 'DOCMP/PEGA Access Token',
  scopes: ['http://localhost:3000/ivc_champva/v1/forms/status_updates'],
  access_token_audience: 'docmp-champva-forms-aws-lambda',
  access_token_user_attributes: [],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certificates: [File.read('spec/fixtures/sign_in/sts_client.crt')]
)

# Create Service Account Config for MHV Account Creation
mhv_ac = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: 'c34b86f2130ff3cd4b1d309bc09d8740')
mhv_ac.update!(
  description: 'MHV Account Creation - localhost',
  scopes: ['https://apigw-intb.aws.myhealth.va.gov/v1/usermgmt/account-service/account',
           'http://localhost:3000/sts/terms_of_use/current_status'],
  access_token_audience: 'http://localhost:3000',
  access_token_user_attributes: ['icn'],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certificates: [File.read('spec/fixtures/sign_in/sts_client.crt')]
)

# Update any exisitng ServiceAccountConfigs and ClientConfigs with default empty arrays
SignIn::ServiceAccountConfig.where(certificates: nil).update(certificates: [])
SignIn::ServiceAccountConfig.where(scopes: nil).update(scopes: [])
SignIn::ClientConfig.where(certificates: nil).update(certificates: [])

# Create UserActionEvents
config_file_path = Rails.root.join('config', 'audit_log', 'user_action_events.yml')
unless File.exist?(config_file_path)
  Rails.logger.info('[UserActionEvent] Setup Error: UserActionEvents config file not found')
  return
end
YAML.load_file(config_file_path).each do |identifier, event_config|
  event = UserActionEvent.find_or_initialize_by(identifier:)
  event.attributes = event_config
  event.save!
rescue => e
  Rails.logger.info("[UserActionEvent] Setup Error: #{e.message}")
end
