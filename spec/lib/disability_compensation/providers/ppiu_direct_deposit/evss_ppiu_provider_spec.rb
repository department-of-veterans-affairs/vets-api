# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/ppiu_direct_deposit/evss_ppiu_provider'
require 'support/disability_compensation_form/shared_examples/ppiu_provider'

RSpec.describe EvssPPIUProvider do
  let(:current_user) do
    create(:evss_user)
  end

  let(:provider) { EvssPPIUProvider.new(current_user) }

  it_behaves_like 'ppiu direct deposit provider'

  it 'retrieves payment information from the evss api' do
    VCR.use_cassette('evss/ppiu/payment_information') do
      response = provider.get_payment_information
      expect(response.class).to eq(EVSS::PPIU::PaymentInformationResponse)
    end
  end
end
