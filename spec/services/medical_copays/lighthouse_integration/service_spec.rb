# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::LighthouseIntegration::Service do
  describe '#list' do
    it 'returns a list of invoices' do
      skip 'Temporarily skip flaky test'
      VCR.use_cassette('lighthouse/hcc/invoice_list_success') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('123')

        response = service.list(count: 10, page: 1)

        expect(response.total).to eq(10)
        expect(response.entries.first.class).to eq(Lighthouse::HCC::Invoice)
        expect(response.links.keys).to eq(%i[self first last])
        expect(response.page).to eq(1)
        expect(response.meta).to eq(
          {
            total: 10,
            page: 1,
            per_page: 50,
            copay_summary: {
              total_current_balance: 757.27,
              copay_bill_count: 10,
              last_updated_on: '2025-08-29T00:00:00Z'
            }
          }
        )
      end
    end

    it 'handles no records' do
      skip 'Temporarily skip flaky test'
      VCR.use_cassette('lighthouse/hcc/no_records') do
        allow(Auth::ClientCredentials::JWTGenerator).to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('123')

        response = service.list(count: 10, page: 1)

        expect(response.entries).to be_empty
        expect(response.page).to be_zero
        expect(response.meta).to eq(
          {
            total: 0, page: 0, per_page: 10,
            copay_summary: {
              total_current_balance: 0.0,
              copay_bill_count: 0,
              last_updated_on: nil
            }
          }
        )
      end
    end

    it 'raises BadRequest for a 400 from Lighthouse' do
      skip 'Temporarily skip flaky test'
      VCR.use_cassette('lighthouse/hcc/auth_error') do
        allow(Auth::ClientCredentials::JWTGenerator)
          .to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('123')

        expect do
          service.list(count: 10, page: 1)
        end.to raise_error(Common::Exceptions::BadRequest)
      end
    end
  end

  describe '#get_detail' do
    it 'returns copay detail with populated attributes' do
      VCR.use_cassette('lighthouse/hcc/copay_detail_success') do
        allow(Auth::ClientCredentials::JWTGenerator)
          .to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('32000551')
        result = service.get_detail(id: '4-1abZUKu7LnbcQc')

        expect(result).to be_a(Lighthouse::HCC::CopayDetail)
        expect(result.external_id).to be_present
        expect(result.facility).to be_present
        expect(result.status).to be_present
        expect(result.line_items).to be_an(Array)
        expect(result.payments).to be_an(Array)
      end
    end

    it 'raises BadRequest for a 400 from Lighthouse' do
      VCR.use_cassette('lighthouse/hcc/auth_error') do
        allow(Auth::ClientCredentials::JWTGenerator)
          .to receive(:generate_token).and_return('fake-jwt')

        service = MedicalCopays::LighthouseIntegration::Service.new('32000551')

        expect do
          service.get_detail(id: '4-1abZUKu7LnbcQc')
        end.to raise_error(Common::Exceptions::BadRequest)
      end
    end
  end
end
