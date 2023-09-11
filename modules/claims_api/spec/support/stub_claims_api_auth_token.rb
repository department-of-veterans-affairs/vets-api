# frozen_string_literal: true

def stub_claims_api_auth_token
  # mock the token service
  allow_any_instance_of(Auth::ClientCredentials::Service)
    .to receive(:get_token).and_return('faketokenvaluehere')
  token = 'faketokenvaluehere' # matches VCR cassette value
  allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
    .to receive(:get_auth_token).and_return(token)
end
