# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::VAOS::FacilityService do
  subject { described_class.new }

  let(:facility_id) { '500' }
  let(:clinic_id) { '6' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe '#perform' do
    let(:facility_response) do
      {
        id: '500',
        facilitiesApiId: 'vha_500',
        vistaSite: '500',
        vastParent: '500',
        type: 'va_health_facility',
        name: 'Johnson & Johnson',
        classification: 'MC',
        timezone: {
          timeZoneId: 'America/New_York'
        },
        lat: 32.78447,
        long: -79.95415,
        phone: {
          main: '123-456-7890',
          fax: '456-892-7890',
          pharmacy: '632-456-6734',
          afterHours: '642-632-8932'
        }
      }
    end
    let(:faraday_response) { double('Faraday::Response') }
    let(:faraday_env) { double('Faraday::Env', status: 200, body: facility_response.to_json) }

    context 'when no facilities data in cache, vaos returns successful response' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .with("/facilities/v2/facilities/#{facility_id}",
                {})
          .and_return(faraday_response)
        allow(faraday_response).to receive(:env).and_return(faraday_env)
      end

      it 'returns facility' do
        response = subject.get_facility(facility_id:)
        expect(response).to eq(facility_response.with_indifferent_access)
      end
    end

    context 'when no clinic data in cache, vaos clinic api returns successful response' do
      let(:clinic_response) do
        {
          data: {
            vistaSite: 534,
            clinicId: clinic_id,
            serviceName: 'CHS NEUROSURGERY VARMA',
            friendlyName: 'CHS NEUROSURGERY VARMA',
            medicalService: 'SURGERY',
            physicalLocation: '1ST FL SPECIALTY MODULE 2',
            phoneNumber: '843-577-5011',
            stationId: '534',
            institutionId: '534',
            stationName: 'Ralph H. Johnson Department of Veterans Affairs Medical Center',
            primaryStopCode: 406,
            primaryStopCodeName: 'NEUROSURGERY',
            secondaryStopCodeName: '*Missing*',
            appointmentLength: 30,
            variableAppointmentLength: true,
            patientDirectScheduling: false,
            patientDisplay: true,
            institutionName: 'CHARLESTON VAMC',
            institutionIEN: '534',
            institutionSID: '97177',
            timezone: {
              timeZoneId: 'America/New_York'
            },
            futureBookingMaximumDays: 390
          }
        }
      end
      let(:faraday_response) { double('Faraday::Response') }
      let(:faraday_env) { double('Faraday::Env', status: 200, body: clinic_response.to_json) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .with("/facilities/v2/facilities/#{facility_id}/clinics/#{clinic_id}",
                {})
          .and_return(faraday_response)
        allow(faraday_response).to receive(:env).and_return(faraday_env)
      end

      it 'returns clinic data' do
        response = subject.get_clinic(facility_id:, clinic_id:)
        expect(response).to eq(clinic_response.with_indifferent_access)
      end
    end

    context 'when facilities api return server error' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(exception)
      end

      it 'throws exception' do
        expect do
          subject.get_facility(facility_id:)
        end.to(raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
        end)
      end
    end

    context 'when clinics api return server error' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(exception)
      end

      it 'throws exception' do
        expect do
          subject.get_clinic(facility_id:, clinic_id:)
        end.to(raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
        end)
      end
    end
  end

  describe 'facilities api data from cache' do
    let(:facility_response) do
      {
        id: '500',
        facilitiesApiId: 'vha_500',
        vistaSite: '500',
        vastParent: '500',
        type: 'va_health_facility',
        name: 'Johnson & Johnson',
        classification: 'MC',
        timezone: {
          timeZoneId: 'America/New_York'
        },
        lat: 32.78447,
        long: -79.95415,
        phone: {
          main: '123-456-7890',
          fax: '456-892-7890',
          pharmacy: '632-456-6734',
          afterHours: '642-632-8932'
        }
      }
    end

    context 'when facility data exists in cache' do
      before do
        Rails.cache.write(
          "check_in.vaos_facility_#{facility_id}",
          facility_response,
          expires_in: 12.hours
        )
      end

      it 'returns facility data from cache' do
        response = subject.get_facility_with_cache(facility_id:)
        expect_any_instance_of(described_class).not_to receive(:perform)
        expect(response).to eq(facility_response)
      end
    end

    context 'when clinic data exists in cache' do
      let(:clinic_response) do
        {
          data: {
            vistaSite: 534,
            clinicId: clinic_id,
            serviceName: 'CHS NEUROSURGERY VARMA',
            friendlyName: 'CHS NEUROSURGERY VARMA',
            stationId: '534',
            primaryStopCode: 406,
            primaryStopCodeName: 'NEUROSURGERY',
            patientDisplay: true,
            timezone: {
              timeZoneId: 'America/New_York'
            },
            futureBookingMaximumDays: 390
          }
        }
      end

      before do
        Rails.cache.write(
          "check_in.vaos_clinic_#{facility_id}_#{clinic_id}",
          clinic_response,
          expires_in: 12.hours
        )
      end

      it 'returns clinic data from cache' do
        response = subject.get_clinic_with_cache(facility_id:, clinic_id:)
        expect_any_instance_of(described_class).not_to receive(:perform)
        expect(response).to eq(clinic_response)
      end
    end
  end
end
