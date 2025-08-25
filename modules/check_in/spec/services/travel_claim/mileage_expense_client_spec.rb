# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::MileageExpenseClient do
  let(:client) { described_class.new }
  let(:tokens) { { veis_token: 'veis-token-123', btsss_token: 'btsss-token-456' } }
  let(:claim_id) { 'claim-uuid-123' }
  let(:date_incurred) { '2024-01-15T10:00:00Z' }
  let(:description) { 'Round trip travel to VA Medical Center' }
  let(:trip_type) { 'RoundTrip' }
  let(:correlation_id) { 'correlation-123' }

  before do
    allow(client).to receive_messages(
      perform: double('Response'),
      settings: double('Settings', claims_base_path: 'test-base-path'),
      subscription_key_headers: { 'Ocp-Apim-Subscription-Key' => 'test-key' }
    )
  end

  describe '#add_mileage_expense' do
    it 'calls perform with correct parameters' do
      expect(client).to receive(:perform).with(
        :post,
        'test-base-path/api/v3/expenses/mileage',
        {
          claimId: claim_id,
          dateIncurred: date_incurred,
          description: 'mileage',
          tripType: 'RoundTrip'
        },
        {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer veis-token-123',
          'X-BTSSS-Token' => 'btsss-token-456',
          'X-Correlation-ID' => correlation_id,
          'Ocp-Apim-Subscription-Key' => 'test-key'
        }
      )

      client.add_mileage_expense(
        tokens:,
        claim_id:,
        date_incurred:,
        correlation_id:
      )
    end

    it 'builds correct request body' do
      expect(client).to receive(:perform) do |_method, _url, body, _headers|
        expect(body[:claimId]).to eq(claim_id)
        expect(body[:dateIncurred]).to eq(date_incurred)
        expect(body[:description]).to eq('mileage')
        expect(body[:tripType]).to eq('RoundTrip')
        double('Response')
      end

      client.add_mileage_expense(
        tokens:,
        claim_id:,
        date_incurred:,
        correlation_id:
      )
    end

    it 'builds correct headers' do
      expect(client).to receive(:perform) do |_method, _url, _body, headers|
        expect(headers['Content-Type']).to eq('application/json')
        expect(headers['Authorization']).to eq('Bearer veis-token-123')
        expect(headers['X-BTSSS-Token']).to eq('btsss-token-456')
        expect(headers['X-Correlation-ID']).to eq(correlation_id)
        double('Response')
      end

      client.add_mileage_expense(
        tokens:,
        claim_id:,
        date_incurred:,
        correlation_id:
      )
    end

    it 'uses correct HTTP method' do
      expect(client).to receive(:perform).with(:post, anything, anything, anything)
      client.add_mileage_expense(
        tokens:,
        claim_id:,
        date_incurred:,
        correlation_id:
      )
    end

    it 'constructs correct URL' do
      expect(client).to receive(:perform).with(anything, 'test-base-path/api/v3/expenses/mileage', anything, anything)
      client.add_mileage_expense(
        tokens:,
        claim_id:,
        date_incurred:,
        correlation_id:
      )
    end
  end

  describe 'inheritance' do
    it 'inherits from BaseClient' do
      expect(described_class.superclass).to eq(TravelClaim::BaseClient)
    end
  end

  describe 'constants' do
    it 'defines EXPENSE_DESCRIPTION constant' do
      expect(described_class::EXPENSE_DESCRIPTION).to eq('mileage')
    end

    it 'defines TRIP_TYPE constant' do
      expect(described_class::TRIP_TYPE).to eq('RoundTrip')
    end
  end

  describe 'private methods' do
    describe '#build_mileage_expense_body' do
      it 'builds body with correct structure' do
        body = client.send(:build_mileage_expense_body,
                           claim_id:, date_incurred:)

        expect(body).to eq({
                             claimId: claim_id,
                             dateIncurred: date_incurred,
                             description: 'mileage',
                             tripType: 'RoundTrip'
                           })
      end

      it 'uses hardcoded trip type and description' do
        body = client.send(:build_mileage_expense_body,
                           claim_id:, date_incurred:)

        expect(body[:tripType]).to eq('RoundTrip')
        expect(body[:description]).to eq('mileage')
      end
    end

    describe '#build_standard_headers' do
      it 'builds headers with correct structure' do
        headers = client.send(:build_standard_headers, tokens, correlation_id)

        expect(headers).to include(
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer veis-token-123',
          'X-BTSSS-Token' => 'btsss-token-456',
          'X-Correlation-ID' => correlation_id
        )
      end

      it 'includes subscription key headers from base client' do
        allow(client).to receive(:subscription_key_headers).and_return({ 'Test-Header' => 'test-value' })

        headers = client.send(:build_standard_headers, tokens, correlation_id)

        expect(headers['Test-Header']).to eq('test-value')
      end
    end
  end

  describe 'edge cases' do
    it 'always uses hardcoded description regardless of input' do
      body = client.send(:build_mileage_expense_body,
                         claim_id:, date_incurred:)

      expect(body[:description]).to eq('mileage')
    end

    it 'handles different date formats' do
      body = client.send(:build_mileage_expense_body,
                         claim_id:, date_incurred: '2024-01-15T10:00:00.000Z')

      expect(body[:dateIncurred]).to eq('2024-01-15T10:00:00.000Z')
    end
  end
end
