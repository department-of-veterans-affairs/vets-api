# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::SystemsService do
  subject { VAOS::V2::SystemsService.new(user) }

  let(:user) { build(:user, :mhv) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_facility_clinics' do
    context 'with 7 clinics' do
      it 'returns an array of size 7' do
        VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method uri]) do
          response = subject.get_facility_clinics(location_id: '983', clinical_service: 'audiology')
          expect(response.size).to eq(7)
          expect(response[0][:id]).to eq('570')
        end
      end
    end

    context 'when the upstream server returns a 400' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/systems/get_facility_clinics_400', match_requests_on: %i[method uri]) do
          expect do
            subject.get_facility_clinics(location_id: '983', clinic_ids: '570', clinical_service: 'audiology')
          end.to raise_error(Common::Exceptions::BackendServiceException, /VAOS_400/)
        end
      end
    end
  end

  describe '#get_available_slots' do
    context 'when the upstream server returns status code 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/systems/get_available_slots_500', match_requests_on: %i[method uri]) do
          expect do
            subject.get_available_slots(location_id: '983', clinic_id: '570',
                                        start_dt: '2021-06-01T00:00:00Z',
                                        end_dt: '2021-12-31T23:59:59Z')
          end.to raise_error(Common::Exceptions::BackendServiceException, /VAOS_502/)
        end
      end
    end

    context 'when the upstream server returns status code 200' do
      it 'returns a list of available slots' do
        VCR.use_cassette('vaos/v2/systems/get_available_slots_200', match_requests_on: %i[method uri]) do
          available_slots = subject.get_available_slots(location_id: '983', clinic_id: '1081',
                                                        start_dt: '2021-05-26T00:00:00Z',
                                                        end_dt: '2021-06-30T23:59:59Z')
          expect(available_slots.size).to eq(401)
          expect(available_slots[400].id).to eq('3230323130363330323133303A323032313036333032323030')
          expect(available_slots[400].start).to eq('2021-06-30T21:30:00Z')
          expect(available_slots[400].end).to eq('2021-06-30T22:00:00Z')
        end
      end
    end
  end
end
