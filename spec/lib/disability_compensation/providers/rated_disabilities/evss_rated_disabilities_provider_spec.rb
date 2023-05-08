# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/rated_disabilities/evss_rated_disabilities_provider'
require 'support/disability_compensation_form/shared_examples/rated_disabilities_provider'

RSpec.describe EvssRatedDisabilitiesProvider do
  let(:current_user) do
    create(:evss_user)
  end

  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  before do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES)
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
  end

  after do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES)
  end

  it_behaves_like 'rated disabilities provider'

  it 'retrieves rated disabilities from the EVSS API' do
    VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
      provider = EvssRatedDisabilitiesProvider.new(auth_headers)
      response = provider.get_rated_disabilities('', '')
      expect(response['rated_disabilities'].length).to eq(2)
    end
  end

  it 'raises an exception if there is an error from EVSS' do
    allow_any_instance_of(Common::Client::Base).to(
      receive(:perform).and_raise(Common::Client::Errors::ClientError)
    )
    expect do
      provider = EvssRatedDisabilitiesProvider.new(auth_headers)
      provider.get_rated_disabilities('', '')
    end.to raise_error Common::Exceptions::BackendServiceException
  end
end
