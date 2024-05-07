# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::VAOS::FacilityService do
  subject { described_class }

  let(:facility_id) { '500' }
  let(:clinic_id) { '6' }

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.new).to be_an_instance_of(described_class)
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

    context 'when vaos returns successful response' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .with("/facilities/v2/facilities/#{facility_id}",
                {})
          .and_return(faraday_response)
        allow(faraday_response).to receive(:env).and_return(faraday_env)
      end

      it 'returns facility' do
        svc = subject.new
        response = svc.get_facility(facility_id:)
        expect(response).to eq(facility_response.with_indifferent_access)
      end
    end

    context 'when vaos clinic api returns successful response' do
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
        svc = subject.new
        response = svc.get_clinic(facility_id:, clinic_id:)
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
        svc = subject.new
        expect do
          svc.get_facility(facility_id:)
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
        svc = subject.new
        expect do
          svc.get_clinic(facility_id:, clinic_id:)
        end.to(raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
        end)
      end
    end
  end
end
