# frozen_string_literal: true

require 'sign_in/constants/auth'

# Create Config for va.gov Sign in Service client
vaweb = SignIn::ClientConfig.find_or_initialize_by(client_id: '6f317064-d9c8-41d9-9158-4d77d20bb0b3')
vaweb.update!(authentication: SignIn::Constants::Auth::COOKIE,
              description: 'VA.gov Web Client',
              anti_csrf: true,
              redirect_uri: 'http://localhost:3001/auth/login/callback',
              access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
              access_token_audience: 'va.gov',
              pkce: true,
              logout_redirect_uri: 'http://localhost:3001',
              enforced_terms: SignIn::Constants::Auth::VA_TERMS,
              terms_of_use_url: 'http://localhost:3001/terms-of-use',
              refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Config for VA flagship mobile Sign in Service client
vamobile = SignIn::ClientConfig.find_or_initialize_by(client_id: '7e2d73b0-d2fd-4f9f-969b-605698dd7a95')
vamobile.update!(authentication: SignIn::Constants::Auth::API,
                 description: 'VA.gov Mobile Client',
                 anti_csrf: false,
                 redirect_uri: 'vamobile://login-success',
                 pkce: true,
                 access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES,
                 access_token_audience: 'vamobile',
                 enforced_terms: SignIn::Constants::Auth::VA_TERMS,
                 terms_of_use_url: 'http://localhost:3001/terms-of-use',
                 refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS)

# Create Config for VA mobile test Sign in Service client
vamobile_mock = SignIn::ClientConfig.find_or_initialize_by(client_id: '4a7d3355-a3d3-4546-82c5-1d8835760f15')
vamobile_mock.update!(authentication: SignIn::Constants::Auth::API,
                      description: 'VA.gov Mobile Test Client',
                      anti_csrf: false,
                      redirect_uri: 'http://localhost:4001/auth/sis/login-success',
                      pkce: true,
                      access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES,
                      access_token_audience: 'vamobile',
                      refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS)

# Create Config for localhost mocked authentication client
vamock = SignIn::ClientConfig.find_or_initialize_by(client_id: 'cf239149-83db-4cda-9269-8fe796c8dc19')
vamock.update!(authentication: SignIn::Constants::Auth::MOCK,
               description: 'VA.gov Mock Client',
               anti_csrf: true,
               pkce: true,
               redirect_uri: 'http://localhost:3001/auth/login/callback',
               access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
               access_token_audience: 'va.gov',
               logout_redirect_uri: 'http://localhost:3001',
               refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Config for example external client using cookie auth
sample_client_web = SignIn::ClientConfig.find_or_initialize_by(client_id: '52af9141-853f-411e-9c00-bee3adbf57a2')
sample_client_web.update!(authentication: SignIn::Constants::Auth::COOKIE,
                          description: 'Sample Cookie Auth Client',
                          anti_csrf: true,
                          pkce: true,
                          redirect_uri: 'http://localhost:4567/auth/result',
                          access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
                          access_token_audience: 'sample_client',
                          logout_redirect_uri: 'http://localhost:4567',
                          refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Config for example external client using api auth
sample_client_api = SignIn::ClientConfig.find_or_initialize_by(client_id: 'd248310c-d398-4068-a8dd-fb3f0a535b41')
sample_client_api.update!(authentication: SignIn::Constants::Auth::API,
                          description: 'Sample API Auth Client',
                          anti_csrf: false,
                          pkce: true,
                          redirect_uri: 'http://localhost:4567/auth/result',
                          access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
                          access_token_audience: 'sample_client',
                          logout_redirect_uri: 'http://localhost:4567',
                          refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Config for VA Identity Dashboard using cookie auth
vaid_dash = SignIn::ClientConfig.find_or_initialize_by(client_id: '521d8378-8283-4756-919f-2dee61175b90')
vaid_dash.update!(authentication: SignIn::Constants::Auth::COOKIE,
                  description: 'VA Identity Dashboard Client',
                  anti_csrf: true,
                  pkce: true,
                  redirect_uri: 'http://localhost:3001/auth/login/callback',
                  access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
                  access_token_audience: 'sample_client',
                  access_token_attributes: %w[first_name last_name email],
                  logout_redirect_uri: 'http://localhost:3001',
                  refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create Service Account Config for VA Identity Dashboard Service Account auth
vaid_certificate = File.read('spec/fixtures/sign_in/identity_dashboard_service_account.crt')
vaid_service_account_id = '01b8ebaac5215f84640ade756b645f28'
vaid_access_token_duration = SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES
identity_dashboard_service_account_config =
  SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: vaid_service_account_id)
identity_dashboard_service_account_config.update!(service_account_id: vaid_service_account_id,
                                                  description: 'VA Identity Dashboard API',
                                                  scopes: ['http://localhost:3000/sign_in/client_configs',
                                                           'http://localhost:3000/v0/account_controls/credential_index',
                                                           'http://localhost:3000/v0/account_controls/credential_lock',
                                                           'http://localhost:3000/v0/account_controls/credential_unlock'],
                                                  access_token_audience: 'http://localhost:4000',
                                                  access_token_duration: vaid_access_token_duration,
                                                  certificates: [vaid_certificate],
                                                  access_token_user_attributes: %w[icn])

# Create Service Account Config for Chatbot
chatbot = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: '88a6d94a3182fd63279ea5565f26bcb4')
chatbot.update!(
  description: 'Chatbot',
  scopes: ['http://localhost:3000/v0/map_services/chatbot/token'],
  access_token_audience: 'http://localhost:3978/api/messages',
  access_token_user_attributes: ['icn'],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certificates: [File.read('spec/fixtures/sign_in/sample_service_account.crt')]
)
