# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::LighthouseIntegration::Service do
  describe '#list' do
    it 'returns a list of invoices' do
      VCR.use_cassette('lighthouse/hccc/invoice_list_success') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('123')

        response = service.list(count: 10, page: 1)

        expect(response.total).to eq(10)
        expect(response.entries.first.class).to eq(Lighthouse::HCC::Invoice)
        expect(response.links.keys).to eq([:self, :first, :last])
        expect(response.page).to eq(1)
      end
    end

    it 'returns a list of invoices' do
      VCR.use_cassette('lighthouse/hccc/no_records') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('123')

        response = service.list(count: 10, page: 1)

        expect(response.entries).to be_empty
        expect(response.page).to be_zero
        expect(response.meta).to eq({:total=>0, :page=>0, :per_page=>50})
      end
    end

    it "raises BadRequest for a 400 from Lighthouse" do
      VCR.use_cassette("lighthouse/hccc/auth_error") do
        allow(Auth::ClientCredentials::JWTGenerator)
          .to receive(:generate_token).and_return("fake-jwt")

        service = MedicalCopays::LighthouseIntegration::Service.new("123")

        expect {
          service.list(count: 10, page: 1)
        }.to raise_error(Common::Exceptions::BadRequest)
      end
    end
  end
end
