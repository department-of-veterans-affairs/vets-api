# frozen_string_literal: true

##
# SignIn::Certificate seeds
##

# vets-api sts clients
sts_client_cert = SignIn::Certificate.find_or_create_by!(pem: File.read('spec/fixtures/sign_in/sts_client.crt'))
identity_dashboard_cert =
  SignIn::Certificate.find_or_create_by!(pem: File.read('spec/fixtures/sign_in/identity_dashboard_service_account.crt'))

##
# SignIn::ServiceAccountConfig seeds
##

# sample sts service account
sample_sts_config = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: 'sample_sts_service_account')
sample_sts_config.update!(
  description: 'Sample STS Service Account',
  scopes: [],
  access_token_audience: 'http://localhost:3000',
  access_token_user_attributes: [],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certs: [sts_client_cert]
)

# identity-dashboard
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
                                                  certs: [identity_dashboard_cert],
                                                  access_token_user_attributes: %w[icn type credential_id])

# Create Service Account Config for Chatbot
chatbot = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: '03f8a6cf626527942e45348f3e40b2ad')
chatbot.update!(
  description: 'Chatbot User Auth',
  scopes: ['http://localhost:3000/v0/chatbot/user'],
  access_token_audience: 'http://localhost:3978/api/messages',
  access_token_user_attributes: [],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certs: [sts_client_cert]
)

# Create Service Account Config for Chatbot
chatbot = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: '88a6d94a3182fd63279ea5565f26bcb4')
chatbot.update!(
  description: 'Chatbot',
  scopes: ['http://localhost:3000/v0/map_services/chatbot/token', 'http://localhost:3000/v0/chatbot/claims'],
  access_token_audience: 'http://localhost:3978/api/messages',
  access_token_user_attributes: ['icn'],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certs: [sts_client_cert]
)

# Create Service Account Config for BTSSS
btsss = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: 'bbb5830ecebdef04556e9c430e374972')
btsss.update!(
  description: 'BTSSS',
  scopes: [],
  access_token_audience: 'http://localhost:3000',
  access_token_user_attributes: ['icn'],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certs: [sts_client_cert]
)

# Create Service Account Config for IVC_Champva
btsss = SignIn::ServiceAccountConfig.find_or_initialize_by(service_account_id: '6747fb5e6bdb18b2f6f0b890ff584b07')
btsss.update!(
  description: 'DOCMP/PEGA Access Token',
  scopes: ['http://localhost:3000/ivc_champva/v1/forms/status_updates'],
  access_token_audience: 'docmp-champva-forms-aws-lambda',
  access_token_user_attributes: [],
  access_token_duration: SignIn::Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES,
  certs: [sts_client_cert]
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
  certs: [sts_client_cert]
)
