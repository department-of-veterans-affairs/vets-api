# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::SystemsService do
  subject { VAOS::V2::SystemsService.new(user) }

  let(:user) { build(:user, :vaos) }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
    Flipper.enable(:va_online_scheduling_use_vpg)
    Flipper.disable(:va_online_scheduling_vaos_alternate_route)
  end

  describe '#get_facility_clinics' do
    context 'using VPG' do
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
        it 'raises a backend exception' do
          VCR.use_cassette('vaos/v2/systems/get_facility_clinics_400_vpg', match_requests_on: %i[method path query]) do
            expect do
              subject.get_facility_clinics(location_id: '983', clinic_ids: '570', clinical_service: 'audiology')
            end.to raise_error(Common::Exceptions::BackendServiceException, /VAOS_400/)
          end
        end
      end
    end
  end
end
