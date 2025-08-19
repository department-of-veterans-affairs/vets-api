# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AppointmentsService do
  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in_session) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:auth_manager) { instance_double(TravelClaim::AuthManager) }
  let(:redis_client) { instance_double(TravelClaim::RedisClient) }
  let(:client) { instance_double(TravelClaim::AppointmentsClient) }
  let(:patient_icn) { '123456789' }
  let(:service) { described_class.new(check_in_session:, auth_manager:) }

  let(:appointment_date_time) { '2024-01-15T10:00:00Z' }
  let(:facility_id) { 'facility-123' }
  let(:correlation_id) { 'correlation-123' }

  before do
    allow(TravelClaim::RedisClient).to receive(:build).and_return(redis_client)
    allow(redis_client).to receive(:icn).with(uuid:).and_return(patient_icn)
    allow(TravelClaim::AppointmentsClient).to receive(:new).and_return(client)
  end

  describe '#initialize' do
    it 'accepts check_in_session parameter' do
      service = described_class.new(check_in_session:)
      expect(service.check_in_session).to eq(check_in_session)
    end

    it 'accepts check_in parameter for backward compatibility' do
      service = described_class.new(check_in: check_in_session)
      expect(service.check_in_session).to eq(check_in_session)
    end

    it 'uses provided auth_manager' do
      service = described_class.new(check_in_session:, auth_manager:)
      expect(service.auth_manager).to eq(auth_manager)
    end

    it 'expects auth_manager to be provided by orchestrator' do
      service = described_class.new(check_in_session:)
      expect(service.auth_manager).to be_nil
    end
  end

  describe '#find_or_create_appointment' do
    let(:mock_response) do
      double('Response', body: { 'data' => [{ 'id' => 'appointment-123' }] })
    end

    before do
      allow(auth_manager).to receive(:request_new_tokens).and_return({
                                                                       veis_token: 'veis-token',
                                                                       btsss_token: 'btsss-token'
                                                                     })
      allow(client).to receive(:find_or_create_appointment).and_return(mock_response)
    end

    it 'validates appointment parameters' do
      expect do
        service.find_or_create_appointment(appointment_date_time: nil, facility_id:, correlation_id:)
      end.to raise_error(ArgumentError, /appointment time cannot be nil/)
    end

    it 'delegates to appointments client with correlation_id' do
      expect(client).to receive(:find_or_create_appointment).with(
        tokens: { veis_token: 'veis-token', btsss_token: 'btsss-token' },
        appointment_date_time:,
        facility_id:,
        patient_icn:,
        correlation_id:
      ).and_return(mock_response)

      result = service.find_or_create_appointment(appointment_date_time:, facility_id:, correlation_id:)
      expect(result[:data]).to eq({ 'id' => 'appointment-123' })
    end

    it 'handles API errors and logs to rails logger' do
      allow(client).to receive(:find_or_create_appointment).and_raise(Common::Exceptions::BackendServiceException)
      allow(Rails.logger).to receive(:error)

      expect do
        service.find_or_create_appointment(appointment_date_time:, facility_id:, correlation_id:)
      end.to raise_error(Common::Exceptions::BackendServiceException)

      expect(Rails.logger).to have_received(:error)
    end

    it 'handles empty response data gracefully' do
      empty_response = double('Response', body: { 'data' => [] })
      allow(client).to receive(:find_or_create_appointment).and_return(empty_response)

      result = service.find_or_create_appointment(appointment_date_time:, facility_id:, correlation_id:)
      expect(result[:data]).to be_nil
    end

    it 'handles malformed response data gracefully' do
      malformed_response = double('Response', body: { 'data' => nil })
      allow(client).to receive(:find_or_create_appointment).and_return(malformed_response)

      result = service.find_or_create_appointment(appointment_date_time:, facility_id:, correlation_id:)
      expect(result[:data]).to be_nil
    end
  end

  describe 'inheritance and modules' do
    it 'is a plain class' do
      expect(described_class.superclass).to eq(Object)
    end

    it 'includes SentryLogging' do
      expect(described_class.included_modules).to include(SentryLogging)
    end
  end

  describe 'private methods' do
    describe '#patient_icn' do
      it 'returns the patient ICN from Redis' do
        expect(service.send(:patient_icn)).to eq(patient_icn)
      end

      it 'memoizes the patient ICN' do
        expect(redis_client).to receive(:icn).with(uuid:).once.and_return(patient_icn)

        service.send(:patient_icn)
        service.send(:patient_icn) # Second call should use memoized value
      end
    end
  end
end
