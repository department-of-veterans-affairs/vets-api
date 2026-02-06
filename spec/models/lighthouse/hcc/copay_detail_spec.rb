# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::HCC::CopayDetail do
  describe 'initialization' do
    context 'with valid invoice data' do
      subject { described_class.new(invoice_data:, account_data:, facility_address:, patient_data:) }

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

      let(:facility_address) do
        {
          address_line1: '123 Test',
          address_line2: nil,
          address_line3: nil,
          city: 'Test City',
          state: 'FL',
          postalCode: '12345'
        }
      end

      let(:patient_data) do
        {
          'resourceType' => 'Bundle',
          'entry' => [
            {
              'resource' => {
                'resourceType' => 'Patient',
                'name' => [{ 'family' => 'DOE', 'given' => %w[JOHN MIDDLE] }],
                'address' => [
                  {
                    'line' => ['123 MAIN ST', 'APT 1'],
                    'city' => 'ANYTOWN',
                    'state' => 'VA',
                    'postalCode' => '12345'
                  }
                ]
              }
            }
          ]
        }
      end

      it 'extracts basic attributes from invoice data' do
        expect(subject.external_id).to eq('invoice-123')
        expect(subject.facility).to include(
          'name' => 'VA Medical Center',
          'address' => include(
            'address_line1' => '123 Test',
            'city' => 'Test City',
            'state' => 'FL',
            'postalCode' => '12345'
          )
        )
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

      it 'extracts patient data from patient FHIR bundle' do
        expect(subject.patient).to include(
          'first_name' => 'JOHN',
          'middle_name' => 'MIDDLE',
          'last_name' => 'DOE',
          'address' => include(
            'address_line1' => '123 MAIN ST',
            'address_line2' => 'APT 1',
            'address_line3' => nil,
            'city' => 'ANYTOWN',
            'state' => 'VA',
            'postalCode' => '12345'
          )
        )
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

        expect(detail.facility).to eq({ 'name' => nil, 'address' => nil })
        expect(detail.bill_number).to be_nil
        expect(detail.status_description).to be_nil
      end

      it 'defaults line_items and payments to empty arrays' do
        invoice_data = { 'id' => 'test-123' }
        detail = described_class.new(invoice_data:)

        expect(detail.line_items).to eq([])
        expect(detail.payments).to eq([])
      end

      it 'handles nil patient_data' do
        invoice_data = { 'id' => 'test-123' }
        detail = described_class.new(invoice_data:, patient_data: nil)

        expect(detail.patient).to be_nil
      end

      it 'handles empty patient bundle' do
        invoice_data = { 'id' => 'test-123' }
        patient_data = { 'resourceType' => 'Bundle', 'entry' => [] }
        detail = described_class.new(invoice_data:, patient_data:)

        expect(detail.patient).to be_nil
      end

      it 'handles patient data with missing name and address' do
        invoice_data = { 'id' => 'test-123' }
        patient_data = {
          'resourceType' => 'Bundle',
          'entry' => [{ 'resource' => { 'resourceType' => 'Patient' } }]
        }
        detail = described_class.new(invoice_data:, patient_data:)

        expect(detail.patient).to include(
          'first_name' => nil,
          'middle_name' => nil,
          'last_name' => nil,
          'address' => include(
            'address_line1' => nil,
            'city' => nil,
            'state' => nil,
            'postalCode' => nil
          )
        )
      end
    end
  end
end
