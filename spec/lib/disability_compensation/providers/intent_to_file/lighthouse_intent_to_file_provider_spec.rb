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

  it 'retrieves intent to file from the Lighthouse API' do
    VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
      response = provider.get_intent_to_file('compensation', '', '')
      expect(response['intent_to_file'].length).to eq(1)
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
