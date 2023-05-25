# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/intent_to_file/evss_intent_to_file_provider'
require 'support/disability_compensation_form/shared_examples/intent_to_file_provider'

RSpec.describe EvssIntentToFileProvider do
  let(:current_user) do
    create(:user)
  end

  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  before do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE)
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
  end

  after do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE)
  end

  it_behaves_like 'intent to file provider'

  it 'retrieves intent to file from the EVSS API' do
    VCR.use_cassette('evss/intent_to_file/intent_to_file') do
      provider = EvssIntentToFileProvider.new(nil, auth_headers)
      response = provider.get_intent_to_file('compensation', '', '')
      expect(response['intent_to_file'].length).to eq(5)
    end
  end

  it 'raises an exception if there is an error from EVSS' do
    allow_any_instance_of(Common::Client::Base).to(
      receive(:perform).and_raise(Common::Client::Errors::ClientError)
    )
    expect do
      provider = EvssIntentToFileProvider.new(nil, auth_headers)
      provider.get_intent_to_file('compensation', '', '')
    end.to raise_error Common::Exceptions::BackendServiceException
  end
end
