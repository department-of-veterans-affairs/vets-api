# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::SystemsService do
  subject { VAOS::V2::SystemsService.new(user) }

  let(:user) { build(:user, :vaos) }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
  end

  describe '#get_facility_clinics' do
    context 'using VAOS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
      end

      context 'with 7 clinics' do
        it 'returns an array of size 7' do
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200', match_requests_on: %i[method path query]) do
            response = subject.get_facility_clinics(location_id: '983', clinical_service: 'audiology')
            expect(response.size).to eq(7)
            expect(response[0][:id]).to eq('570')
          end
        end

        context 'when the upstream server returns a 400' do
          it 'raises a backend exception' do
            VCR.use_cassette('vaos/v2/systems/get_facility_clinics_400', match_requests_on: %i[method path query]) do
              expect do
                subject.get_facility_clinics(location_id: '983', clinic_ids: '570', clinical_service: 'audiology')
              end.to raise_error(Common::Exceptions::BackendServiceException, /VAOS_400/)
            end
          end
        end
      end
    end

    context 'using VPG' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(true)
      end

      context 'with 7 clinics' do
        it 'returns an array of size 7' do
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_200_vpg', match_requests_on: %i[method path query]) do
            response = subject.get_facility_clinics(location_id: '983', clinical_service: 'audiology')
            expect(response.size).to eq(7)
            expect(response[0][:id]).to eq('570')
          end
        end
      end

      context 'when the upstream server returns a 400' do
        before do
          allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
        end

        it 'raises a backend exception' do
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_400', match_requests_on: %i[method path query]) do
            expect do
              subject.get_facility_clinics(location_id: '983', clinic_ids: '570', clinical_service: 'audiology')
            end.to raise_error(Common::Exceptions::BackendServiceException, /VAOS_400/)
          end
        end
      end
    end
  end

  describe '#get_available_slots' do
    context 'using VAOS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_use_vpg, user).and_return(false)
      end

      context 'when the upstream server returns status code 500' do
        it 'raises a backend exception' do
          VCR.use_cassette('vaos/v2/systems/get_available_slots_500', match_requests_on: %i[method path query]) do
            expect do
              subject.get_available_slots({ location_id: '983',
                                            clinic_id: '1081',
                                            start_dt: '2021-10-01T00:00:00Z',
                                            end_dt: '2021-12-31T23:59:59Z' })
            end.to raise_error(Common::Exceptions::BackendServiceException, /VAOS_502/)
          end
        end
      end

      context 'when the upstream server returns status code 200' do
        it 'returns a list of available slots' do
          VCR.use_cassette('vaos/v2/systems/get_available_slots_200', match_requests_on: %i[method path query]) do
            available_slots = subject.get_available_slots({ location_id: '983',
                                                            clinic_id: '1081',
                                                            start_dt: '2021-10-26T00:00:00Z',
                                                            end_dt: '2021-12-30T23:59:59Z' })
            expect(available_slots.size).to eq(730)
            expect(available_slots[400].id).to eq('3230323131323031323130303A323032313132303132313330')
            expect(available_slots[400].start).to eq('2021-12-01T21:00:00Z')
            expect(available_slots[400].end).to eq('2021-12-01T21:30:00Z')
          end
        end
      end
    end
  end
end
