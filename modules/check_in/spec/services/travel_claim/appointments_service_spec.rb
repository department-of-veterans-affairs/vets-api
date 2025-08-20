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
      service = described_class.new(check_in_session:, auth_manager:)
      expect(service.check_in_session).to eq(check_in_session)
    end

    it 'uses provided auth_manager' do
      service = described_class.new(check_in_session:, auth_manager:)
      expect(service.auth_manager).to eq(auth_manager)
    end

    it 'requires both parameters' do
      expect { described_class.new }.to raise_error(ArgumentError)
      expect { described_class.new(check_in_session:) }.to raise_error(ArgumentError)
      expect { described_class.new(auth_manager:) }.to raise_error(ArgumentError)
    end
  end

  describe '#find_or_create_appointment' do
    let(:mock_response) do
      double('Response', body: { 'data' => [{ 'id' => 'appointment-123' }] })
    end

    before do
      allow(auth_manager).to receive(:authorize).and_return({
                                                              veis_token: 'veis-token',
                                                              btsss_token: 'btsss-token'
                                                            })
      allow(client).to receive(:find_or_create_appointment).and_return(mock_response)
    end

    it 'validates appointment parameters' do
      expect do
        service.find_or_create_appointment(appointment_date_time: nil, facility_id:, correlation_id:)
      end.to raise_error(ArgumentError, /appointment date cannot be nil/)
    end

    it 'validates ISO format for appointment date' do
      expect do
        service.find_or_create_appointment(appointment_date_time: 'invalid-date', facility_id:,
                                           correlation_id:)
      end.to raise_error(ArgumentError, /Expected ISO 8601 format/)
    end

    it 'accepts valid ISO format dates' do
      expect do
        service.find_or_create_appointment(appointment_date_time: '2024-01-15T10:00:00Z', facility_id:,
                                           correlation_id:)
      end.not_to raise_error
    end

    it 'rejects malformed ISO dates' do
      expect do
        service.find_or_create_appointment(appointment_date_time: '0000-00-0T00:00:00.000Z', facility_id:,
                                           correlation_id:)
      end.to raise_error(ArgumentError, /Expected ISO 8601 format/)
    end

    it 'delegates to appointments client with correlation_id' do
      expect(client).to receive(:find_or_create_appointment).with(
        tokens: { veis_token: 'veis-token', btsss_token: 'btsss-token' },
        appointment_date_time:,
        facility_id:,
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

    it 'is a plain class without SentryLogging' do
      expect(described_class.included_modules).not_to include(SentryLogging)
    end
  end

  describe 'private methods' do
    describe '#valid_iso_format?' do
      it 'returns true for valid ISO 8601 strings' do
        expect(service.send(:valid_iso_format?, '2024-01-15T10:00:00Z')).to be true
        expect(service.send(:valid_iso_format?, '2024-01-15T10:00:00.000Z')).to be true
      end

      it 'returns false for invalid date strings' do
        expect(service.send(:valid_iso_format?, 'invalid-date')).to be false
        expect(service.send(:valid_iso_format?, '0000-00-0T00:00:00.000Z')).to be false
      end

      it 'returns false for non-string inputs' do
        expect(service.send(:valid_iso_format?, nil)).to be false
        expect(service.send(:valid_iso_format?, 123)).to be false
        expect(service.send(:valid_iso_format?, Date.new(2024, 1, 15))).to be false
      end
    end

    describe '#make_appointment_request' do
      it 'calls client with correct parameters' do
        tokens = { veis_token: 'test-veis', btsss_token: 'test-btsss' }
        mock_response = double('Response', body: { 'data' => [{ 'id' => 'test-appointment' }] })

        expect(client).to receive(:find_or_create_appointment).with(
          tokens:,
          appointment_date_time:,
          facility_id:,
          correlation_id:
        ).and_return(mock_response)

        service.send(:make_appointment_request, tokens, appointment_date_time, facility_id, correlation_id)
      end
    end
  end
end
