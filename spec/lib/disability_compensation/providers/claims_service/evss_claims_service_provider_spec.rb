# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/claims_service/evss_claims_service_provider'
require 'support/disability_compensation_form/shared_examples/claims_service_provider'

RSpec.describe EvssClaimsServiceProvider do
  let(:current_user) do
    create(:user)
  end

  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  before do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_CLAIMS_SERVICE)
    # allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
  end

  after do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_CLAIMS_SERVICE)
  end

  it_behaves_like 'claims service provider'

  it 'retrieves claims rom the EVSS API' do
    VCR.use_cassette('evss/claims/claims', match_requests_on: %i[uri method body]) do
      provider = EvssClaimsServiceProvider.new(auth_headers)
      response = provider.all_claims
      expect(response['open_claims'].length).to eq(3)
    end
  end
end
