# frozen_string_literal: true

RSpec.shared_context 'with service account authentication' do |service_account_id, scopes, optional_claims = {}|
  let(:service_account_auth_header) { { 'Authorization' => "Bearer #{encoded_service_account_access_token}" } }
  let(:encoded_service_account_access_token) do
    SignIn::ServiceAccountAccessTokenJwtEncoder.new(service_account_access_token:).perform
  end
  let(:service_account_access_token) do
    create(
      :service_account_access_token,
      **optional_claims.merge(
        {
          service_account_id: service_account_config.service_account_id,
          scopes: service_account_config.scopes
        }
      )
    )
  end
  let(:service_account_config) do
    create(:service_account_config, service_account_id:, scopes:)
  end
end
