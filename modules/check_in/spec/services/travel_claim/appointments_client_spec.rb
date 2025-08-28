# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AppointmentsClient do
  let(:client) { described_class.new }
  let(:veis_token) { 'veis-token-123' }
  let(:btsss_token) { 'btsss-token-456' }
  let(:tokens) { { veis_token:, btsss_token: } }
  let(:appointment_date_time) { '2024-01-15T00:00:00Z' }
  let(:facility_id) { 'facility-123' }
  let(:correlation_id) { 'correlation-123' }

  describe '#find_or_create_appointment' do
    it 'uses perform method to make appointment request' do
      expected_body = {
        appointmentDateTime: appointment_date_time,
        facilityStationNumber: facility_id
      }

      expected_headers = hash_including(
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{veis_token}",
        'X-BTSSS-Token' => btsss_token,
        'X-Correlation-ID' => correlation_id
      )

      expect(client).to receive(:perform).with(
        :post,
        kind_of(String),
        expected_body,
        expected_headers
      ).and_return(double('Response'))

      client.find_or_create_appointment(
        tokens:,
        appointment_date_time:,
        facility_id:,
        correlation_id:
      )
    end

    it 'raises BackendServiceException when the Travel Claim API call fails' do
      allow(client).to receive(:perform).and_raise(Common::Exceptions::BackendServiceException, 'API call failed')

      expect do
        client.find_or_create_appointment(
          tokens:,
          appointment_date_time:,
          facility_id:,
          correlation_id:
        )
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end
  end

  describe 'private methods' do
    describe '#build_appointment_body' do
      it 'builds correct request body with camelCase keys' do
        result = client.send(:build_appointment_body,
                             appointment_date_time: '2024-01-15T10:00Z',
                             facility_id: 'facility-123')

        expect(result).to eq({
                               appointmentDateTime: '2024-01-15T10:00Z',
                               facilityStationNumber: 'facility-123'
                             })
      end
    end

    describe '#build_appointment_headers' do
      it 'builds headers with authentication tokens and correlation ID' do
        result = client.send(:build_appointment_headers, tokens, correlation_id)

        expect(result).to include(
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer veis-token-123',
          'X-BTSSS-Token' => 'btsss-token-456',
          'X-Correlation-ID' => 'correlation-123'
        )
      end

      it 'includes claim headers from base client' do
        allow(client).to receive(:settings).and_return(
          double('Settings', subscription_key: 'test-subscription-key')
        )
        allow(Settings).to receive(:vsp_environment).and_return('development')

        result = client.send(:build_appointment_headers, tokens, correlation_id)

        expect(result).to include('Ocp-Apim-Subscription-Key' => 'test-subscription-key')
      end
    end
  end
end
