# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/ppiu_direct_deposit/lighthouse_ppiu_provider'
require 'support/disability_compensation_form/shared_examples/ppiu_provider'

RSpec.describe LighthousePPIUProvider do
  let(:current_user) { build(:user, :loa3, icn: '1012666073V986297') }
  let(:provider) { LighthousePPIUProvider.new(current_user) }

  before do
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
  end

  it_behaves_like 'ppiu direct deposit provider'

  it 'retrieves payment information from the lighthouse api' do
    VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
      response = provider.get_payment_information
      expect(response.class).to eq(DisabilityCompensation::ApiProvider::PaymentInformationResponse)
      expect(response.responses.first.class).to eq(DisabilityCompensation::ApiProvider::PaymentInformation)
      expect(response.responses.first.payment_account.account_number).to eq('1234567890')
      expect(response.responses.first.payment_account.account_type).to eq('Checking')
      expect(response.responses.first.payment_account.financial_institution_routing_number).to eq('031000503')
      expect(response.responses.first.payment_account.financial_institution_name).to eq('WELLS FARGO BANK')
    end
  end

  Lighthouse::ServiceException::ERROR_MAP.except(422, 499, 501).each do |status, error_class|
    it "throws a #{status} error if Lighthouse sends it back" do
      expect do
        test_error(
          "lighthouse/direct_deposit/show/errors/#{status}_response"
        )
      end.to raise_error error_class
    end
  end

  def test_error(cassette_path)
    VCR.use_cassette(cassette_path) do
      provider.get_payment_information
    end
  end
end
