# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::SystemsService do
  subject { VAOS::V2::SystemsService.new(user) }

  let(:user) { build(:user, :mhv) }
  let(:location_id) { 442 }
  let(:patient_icn) { 321 }
  let(:clinic_ids) { %w[111 222 333] }
  let(:clinical_service) { 'primaryCare' }
  let(:page_size) { 0 }
  let(:page_number) { 0 }
  let(:params) do
    {
      location_id: location_id,
      patient_icn: patient_icn,
      clinic_ids: clinic_ids,
      clinical_service: clinical_service,
      page_size: page_size,
      page_number: page_number
    }
  end

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_facility_clinics' do
    context 'with 3 clinics' do
      it 'returns an array of size 3' do
        VCR.use_cassette('vaos/v2/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
          response = subject.get_facility_clinics(params)
          expect(response.size).to eq(3)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/systems/get_facility_clinics_500', match_requests_on: %i[method uri]) do
          expect do
            subject.get_facility_clinics(params)
          end.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_available_slots' do
    let(:slots_params) do
      {
        location_id: '534gd',
        clinic_id: '333',
        start: '2020-01-01T00:00:00Z',
        end: '2020-12-31T23:59:59Z'
      }
    end

    context 'when the upstream server returns status code 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/systems/get_available_slots_500', match_requests_on: %i[method uri]) do
          expect { subject.get_available_slots(slots_params) }
            .to raise_error do |error|
              expect(error).to be_a(Common::Exceptions::BackendServiceException)
              expect(error.status_code).to eq(502)
            end
        end
      end
    end

    context 'when the upstream server returns status code 200' do
      it 'returns a list of available slots' do
        VCR.use_cassette('vaos/v2/systems/get_available_slots_200', match_requests_on: %i[method uri]) do
          available_slots = subject.get_available_slots(slots_params)
          expect(available_slots.size).to eq(3)
          expect(available_slots[1].id).to eq('ce1c5976-e96c-4e9b-9fed-ca1150cf4296')
          expect(available_slots[1].start).to eq('2020-01-01T12:30:00Z')
          expect(available_slots[1].end).to eq('2020-01-01T13:00:00Z')
        end
      end
    end
  end
end
