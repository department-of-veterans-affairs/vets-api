# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/rated_disabilities/lighthouse_rated_disabilities_provider'
require 'support/disability_compensation_form/shared_examples/rated_disabilities_provider'
require 'lighthouse/service_exception'

RSpec.describe LighthouseRatedDisabilitiesProvider do
  let(:current_user) { build(:user, :loa3) }

  before(:all) do
    @provider = LighthouseRatedDisabilitiesProvider.new('123498767V234859')
  end

  before do
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
  end

  it_behaves_like 'rated disabilities provider'

  it 'retrieves rated disabilities from the Lighthouse API' do
    VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
      response = @provider.get_rated_disabilities('', '')
      expect(response.rated_disabilities.length).to eq(1)
    end
  end

  it 'returns the proper error through the Timeout class' do
    allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
    expect do
      @provider.get_rated_disabilities('', '')
    end.to raise_error(Common::Exceptions::Timeout)
  end

  it 'returns the proper error through the ServiceError class' do
    allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::ServerError.new(status: nil))
    expect do
      @provider.get_rated_disabilities('', '')
    end.to raise_error(Common::Exceptions::ServiceError)
  end

  Lighthouse::ServiceException::ERROR_MAP.except(422, 499, 501).each do |status, error_class|
    it "throws a #{status} error if Lighthouse sends it back" do
      expect do
        test_error(
          "lighthouse/veteran_verification/disability_rating/#{status == 404 ? '404_ICN' : status}_response"
        )
      end.to raise_error error_class
    end

    def test_error(cassette_path)
      VCR.use_cassette(cassette_path) do
        @provider.get_rated_disabilities('', '')
      end
    end
  end
end
