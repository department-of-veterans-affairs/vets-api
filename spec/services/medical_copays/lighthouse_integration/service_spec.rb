# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::LighthouseIntegration::Service do
  describe '#list' do
    it 'returns a list of invoices' do
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

  describe '#summary' do
    let(:icn) { '123' }
    let(:service) { described_class.new(icn) }
    let(:invoice_service) { instance_double(Lighthouse::HealthcareCostAndCoverage::Invoice::Service) }

    before do
      allow(service).to receive(:invoice_service).and_return(invoice_service)
    end

    def invoice_entry(date:, balance:)
      {
        'resource' => {
          'date' => date,
          'totalPriceComponent' => [
            {
              'type' => 'base',
              'amount' => { 'value' => balance }
            },
            {
              'type' => 'informational',
              'code' => { 'text' => 'Original Amount' },
              'amount' => { 'value' => balance }
            }
          ]
        }
      }
    end

    it 'aggregates total amount and count within the month window' do
      now = Time.current.utc

      entries = [
        invoice_entry(date: now.iso8601, balance: 10.50),
        invoice_entry(date: now.iso8601, balance: 20.25)
      ]

      allow(invoice_service).to receive(:list)
        .with(count: 50, page: 1)
        .and_return({ 'entry' => entries })

      allow(invoice_service).to receive(:list)
        .with(count: 50, page: 2)
        .and_return({ 'entry' => [] })

      result = service.summary(month_count: 6)

      expect(result).to eq(
        entries: [],
        meta: {
          total_amount_due: 30.75,
          total_copays: 2,
          month_window: 6
        }
      )
    end

    it 'stops processing when an invoice is older than the window' do
      recent = Time.current.utc
      old = 7.months.ago.utc

      entries = [
        invoice_entry(date: recent.iso8601, balance: 15.00),
        invoice_entry(date: old.iso8601, balance: 999.99) # should be ignored
      ]

      allow(invoice_service).to receive(:list)
        .with(count: 50, page: 1)
        .and_return({ 'entry' => entries })

      result = service.summary(month_count: 6)

      expect(result[:meta][:total_amount_due]).to eq(15.0)
      expect(result[:meta][:total_copays]).to eq(1)
    end

    it 'skips entries without a date' do
      entries = [
        { 'resource' => {} },
        invoice_entry(date: Time.current.utc.iso8601, balance: 12.00)
      ]

      allow(invoice_service).to receive(:list)
        .with(count: 50, page: 1)
        .and_return({ 'entry' => entries })

      result = service.summary

      expect(result[:meta][:total_amount_due]).to eq(12.0)
      expect(result[:meta][:total_copays]).to eq(1)
    end

    it 'returns zero totals when no entries are returned' do
      allow(invoice_service).to receive(:list)
        .with(count: 50, page: 1)
        .and_return({ 'entry' => [] })

      result = service.summary

      expect(result).to eq(
        entries: [],
        meta: {
          total_amount_due: 0.0,
          total_copays: 0,
          month_window: 6
        }
      )
    end
  end
end
