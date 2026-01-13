# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::HCC::CopayDetail do
  describe 'initialization' do
    context 'with valid invoice data' do
      subject { described_class.new(invoice_data:, account_data:) }

      let(:invoice_data) do
        {
          'id' => 'invoice-123',
          'issuer' => { 'display' => 'VA Medical Center' },
          'identifier' => [{ 'value' => 'BILL-001' }],
          'status' => 'issued',
          '_status' => { 'valueCodeableConcept' => { 'text' => 'Active' } },
          'date' => '2025-01-15'
        }
      end

      let(:account_data) do
        { 'identifier' => [{ 'value' => 'ACCT-999' }] }
      end

      it 'extracts basic attributes from invoice data' do
        expect(subject.external_id).to eq('invoice-123')
        expect(subject.facility).to eq('VA Medical Center')
        expect(subject.bill_number).to eq('BILL-001')
        expect(subject.status).to eq('issued')
        expect(subject.status_description).to eq('Active')
        expect(subject.invoice_date).to eq('2025-01-15')
      end

      it 'extracts account number from account data' do
        expect(subject.account_number).to eq('ACCT-999')
      end

      it 'calculates payment due date as invoice date plus 30 days' do
        expect(subject.payment_due_date).to eq('2025-02-14')
      end
    end

    context 'with missing or invalid data' do
      it 'handles nil invoice_date' do
        invoice_data = { 'id' => 'test-123', 'date' => nil }
        detail = described_class.new(invoice_data:)

        expect(detail.payment_due_date).to be_nil
      end

      it 'handles invalid invoice_date format' do
        invoice_data = { 'id' => 'test-123', 'date' => 'not-a-date' }
        detail = described_class.new(invoice_data:)

        expect(detail.payment_due_date).to be_nil
      end

      it 'handles nil account_data' do
        invoice_data = { 'id' => 'test-123' }
        detail = described_class.new(invoice_data:, account_data: nil)

        expect(detail.account_number).to be_nil
      end

      it 'handles missing nested keys gracefully' do
        invoice_data = { 'id' => 'test-123' }
        detail = described_class.new(invoice_data:)

        expect(detail.facility).to be_nil
        expect(detail.bill_number).to be_nil
        expect(detail.status_description).to be_nil
      end

      it 'defaults line_items and payments to empty arrays' do
        invoice_data = { 'id' => 'test-123' }
        detail = described_class.new(invoice_data:)

        expect(detail.line_items).to eq([])
        expect(detail.payments).to eq([])
      end
    end
  end
end
