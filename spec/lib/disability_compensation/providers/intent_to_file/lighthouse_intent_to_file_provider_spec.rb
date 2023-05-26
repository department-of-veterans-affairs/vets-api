# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/intent_to_file/lighthouse_intent_to_file_provider'
require 'support/disability_compensation_form/shared_examples/intent_to_file_provider'

RSpec.describe LighthouseIntentToFileProvider do
  let(:current_user) { build(:user, :loa3) }
  let(:provider) { LighthouseIntentToFileProvider.new(current_user) }

  before do
    Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE)
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_token')
  end

  after do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_INTENT_TO_FILE)
  end

  it_behaves_like 'intent to file provider'

  # TODO-BDEX: Down the line, revisit re-generating cassettes using some local test credentials
  # and actual interaction with LH
  it 'retrieves intent to file from the Lighthouse API' do
    VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
      response = provider.get_intent_to_file('compensation', '', '')
      expect(response['intent_to_file'].length).to eq(1)
    end
  end

  it 'creates intent to file using the Lighthouse API' do
    VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
      response = provider.create_intent_to_file('compensation', '', '')
      expect(response).to be_an_instance_of(DisabilityCompensation::ApiProvider::IntentToFilesResponse)
      expect(response['intent_to_file'][0]['type']).to eq('compensation')
      expect(response['intent_to_file'][0]['id']).to be_present
    end
  end

  it 'creates intent to file with the survivor type' do
    VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_survivor_200_response') do
      response = provider.create_intent_to_file('survivor', '', '')
      expect(response).to be_an_instance_of(DisabilityCompensation::ApiProvider::IntentToFilesResponse)
      expect(response['intent_to_file'][0]['type']).to eq('survivor')
      expect(response['intent_to_file'][0]['id']).to be_present
    end
  end

  Lighthouse::ServiceException::ERROR_MAP.each do |status, error_class|
    it "throws a #{status} error if Lighthouse sends it back" do
      expect do
        test_error(
          "lighthouse/benefits_claims/intent_to_file/#{status}_response"
        )
      end.to raise_error error_class
    end

    def test_error(cassette_path)
      VCR.use_cassette(cassette_path) do
        provider.get_intent_to_file('compensation', '', '')
      end
    end
  end
end
