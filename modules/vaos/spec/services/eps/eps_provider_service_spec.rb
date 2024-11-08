# frozen_string_literal: true

require 'rails_helper'

describe VAOS::Eps::EpsProviderService do
  let(:user) { build(:user, :vaos) }
  let(:service) { described_class.new(user) }
  let(:appointment_id) { 'appointment_id' }
  let(:patient_id) { 'patient_id' }
  let(:referral_number) { 'referral_number' }
  let(:network_id) { 'network_id' }
  let(:provider_service_id) { 'provider_service_id' }
  let(:slot_id) { 'slot_id' }
  let(:additional_patient_attributes) { { address: { city: 'Anytown' } } }
  let(:origin) { { latitude: 0.0, longitude: 0.0 } }
  let(:destinations) { { 'destination_id' => { latitude: 0.0, longitude: 0.0 } } }

  describe '#get_appointment' do
    it 'returns an appointment' do
      VCR.use_cassette('vaos/eps/eps_provider_service/get_appointment', match_requests_on: %i[method path query]) do
        response = service.get_appointment(appointment_id)
        expect(response).to be_an(OpenStruct)
      end
    end
  end

  describe '#create_appointment' do
    it 'creates an appointment' do
      VCR.use_cassette('vaos/eps/eps_provider_service/create_appointment', match_requests_on: %i[method path query]) do
        response = service.create_appointment(patient_id, referral_number)
        expect(response).to be_an(OpenStruct)
      end
    end
  end

  describe '#submit_appointment' do
    it 'submits an appointment' do
      VCR.use_cassette('vaos/eps/eps_provider_service/submit_appointment', match_requests_on: %i[method path query]) do
        response = service.submit_appointment(additional_patient_attributes, network_id, provider_service_id, referral_number, [slot_id])
        expect(response).to be_an(OpenStruct)
      end
    end
  end

  describe '#calculate_drive_times' do
    it 'calculates drive times' do
      VCR.use_cassette('vaos/eps/eps_provider_service/calculate_drive_times', match_requests_on: %i[method path query]) do
        response = service.calculate_drive_times(destinations, origin)
        expect(response).to be_an(OpenStruct)
      end
    end
  end

  describe '#get_provider_services' do
    it 'returns provider services' do
      VCR.use_cassette('vaos/eps/eps_provider_service/get_provider_services', match_requests_on: %i[method path query]) do
        response = service.get_provider_services
        expect(response).to be_an(OpenStruct)
      end
    end
  end

  describe '#get_provider_service' do
    it 'returns a provider service' do
      VCR.use_cassette('vaos/eps/eps_provider_service/get_provider_service', match_requests_on: %i[method path query]) do
        response = service.get_provider_service(provider_service_id)
        expect(response).to be_an(OpenStruct)
      end
    end
  end

  describe '#get_provider_service_slots' do
    it 'returns provider service slots' do
      VCR.use_cassette('vaos/eps/eps_provider_service/get_provider_service_slots', match_requests_on: %i[method path query]) do
        response = service.get_provider_service_slots(provider_service_id)
        expect(response).to be_an(OpenStruct)
      end
    end
  end

  describe '#get_provider_service_slot' do
    it 'returns a provider service slot' do
      VCR.use_cassette('vaos/eps/eps_provider_service/get_provider_service_slot', match_requests_on: %i[method path query]) do
        response = service.get_provider_service_slot(provider_service_id, slot_id)
        expect(response).to be_an(OpenStruct)
      end
    end
  end
end