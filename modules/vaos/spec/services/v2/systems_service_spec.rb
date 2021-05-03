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
end
