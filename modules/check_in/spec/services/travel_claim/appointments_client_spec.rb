# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AppointmentsClient do
  let(:client) { described_class.new }
  let(:veis_token) { 'veis-token-123' }
  let(:btsss_token) { 'btsss-token-456' }
  let(:tokens) { { veis_token:, btsss_token: } }
  let(:appointment_date_time) { '2024-01-15T10:00:00Z' }
  let(:facility_id) { 'facility-123' }
  let(:patient_icn) { '123V456' }
  let(:correlation_id) { 'correlation-123' }

  describe '#find_or_create_appointment' do
    it 'uses perform method to make appointment request' do
      expected_body = {
        appointmentDateTime: appointment_date_time,
        facilityId: facility_id,
        patientIcn: patient_icn
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
        patient_icn:,
        correlation_id:
      )
    end
  end
end
