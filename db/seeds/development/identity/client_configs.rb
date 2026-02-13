# frozen_string_literal: true

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
              refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES,
              service_levels: SignIn::Constants::Auth::ACR_VALUES)

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

# Create Config for localhost mocked vets-api with "Production" Mobile Dev Tools
vamobile_local_auth = SignIn::ClientConfig.find_or_initialize_by(client_id: 'vamobile_local_auth')
vamobile_local_auth.update!(authentication: SignIn::Constants::Auth::API,
                            anti_csrf: false,
                            redirect_uri: 'https://va-mobile-dev-tools-0cb741eb06ae.herokuapp.com/auth/login-success',
                            pkce: true,
                            access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_LONG_MINUTES,
                            access_token_audience: 'vamobile',
                            refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_LONG_DAYS)

# Create Config for VA Identity Dashboard using cookie auth
vaid_dash = SignIn::ClientConfig.find_or_initialize_by(client_id: 'identity_dashboard_rails')
vaid_dash.update!(authentication: SignIn::Constants::Auth::API,
                  anti_csrf: false,
                  pkce: true,
                  redirect_uri: 'http://localhost:4000/sessions/callback',
                  access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
                  access_token_audience: 'identity dashboard',
                  access_token_attributes: %w[first_name last_name email],
                  logout_redirect_uri: 'http://localhost:4000/sessions/logout_callback',
                  refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES)

# Create config for accredited_representative_portal
arp = SignIn::ClientConfig.find_or_initialize_by(client_id: 'arp')
arp.update!(authentication: SignIn::Constants::Auth::COOKIE,
            anti_csrf: true,
            pkce: true,
            description: 'Accredited Representative Portal',
            redirect_uri: 'http://localhost:3001/auth/login/callback',
            access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
            access_token_attributes: %w[first_name last_name email all_emails],
            refresh_token_duration: SignIn::Constants::RefreshToken::VALIDITY_LENGTH_SHORT_MINUTES,
            logout_redirect_uri: 'http://localhost:3001/representative',
            credential_service_providers: [SignIn::Constants::Auth::IDME, SignIn::Constants::Auth::LOGINGOV],
            service_levels: [SignIn::Constants::Auth::LOA3, SignIn::Constants::Auth::IAL2])

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

# Create Config for mobile mocked authentication client
vamock_mobile = SignIn::ClientConfig.find_or_initialize_by(client_id: 'vamock-mobile')
vamock_mobile.update!(authentication: SignIn::Constants::Auth::MOCK,
                      anti_csrf: false,
                      pkce: true,
                      redirect_uri: 'vamobile://login-success',
                      access_token_duration: SignIn::Constants::AccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
                      access_token_audience: 'vamobile',
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
