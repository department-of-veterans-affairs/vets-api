# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/ppiu_direct_deposit/evss_ppiu_provider'
require 'support/disability_compensation_form/shared_examples/ppiu_provider'

RSpec.describe EvssPPIUProvider do
  let(:current_user) do
    create(:evss_user)
  end

  let(:provider) { EvssPPIUProvider.new(current_user) }

  context 'PPIU rejection flag disabled' do
    before do
      Flipper.disable(:profile_ppiu_reject_requests)
    end

    it_behaves_like 'ppiu direct deposit provider'

    it 'retrieves payment information from the evss api' do
      VCR.use_cassette('evss/ppiu/payment_information') do
        response = provider.get_payment_information
        expect(response.class).to eq(EVSS::PPIU::PaymentInformationResponse)
      end
    end
  end

  context 'PPIU rejection flag enabled' do
    before do
      Flipper.enable(:profile_ppiu_reject_requests)
    end

    it 'rejects access' do
      VCR.use_cassette('evss/ppiu/payment_information') do
        expect { PPIUPolicy.new(current_user, :ppiu).access? }.to raise_error Common::Exceptions::Forbidden do |e|
          expect(e.errors.first.source).to eq('PPIU Policy')
          expect(e.errors.first.detail).to eq('The EVSS PPIU endpoint will be decommissioned. Access is blocked.')
        end
      end
    end
  end
end
