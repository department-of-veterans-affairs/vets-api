# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/claims_service/lighthouse_claims_service_provider'
require 'support/disability_compensation_form/shared_examples/claims_service_provider'
require 'lighthouse/service_exception'

RSpec.describe LighthouseClaimsServiceProvider do
  let(:current_user) { build(:user, :loa3) }

  before(:all) do
    @provider = LighthouseClaimsServiceProvider.new('123456')
  end

  before do
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
  end

  it_behaves_like 'claims service provider'

  it 'retrieves claim service from the Lighthouse API' do
    VCR.use_cassette('lighthouse/claims/200_response') do
      response = @provider.all_claims('', '')
      expect(response.open_claims.length).to eq(1)
    end
  end

  Lighthouse::ServiceException::ERROR_MAP.except(422, 499, 501).each do |status, error_class|
    it "throws a #{status} error if Lighthouse sends it back" do
      expect do
        test_error("lighthouse/claims/#{status}_response")
      end.to raise_error error_class
    end

    def test_error(cassette_path)
      VCR.use_cassette(cassette_path) do
        @provider.all_claims('', '')
      end
    end
  end
end
