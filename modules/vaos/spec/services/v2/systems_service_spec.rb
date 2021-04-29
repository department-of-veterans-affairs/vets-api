# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::SystemsService do
  subject { VAOS::V2::SystemsService.new(user) }

  let(:user) { build(:user, :mhv) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  let(:location_id) { 442 }
  let(:patient_icn) { 54321 }
  let(:clinic_ids) { %w[111 222 333] }
  let(:clinical_service) { "primaryCare" }
  let(:page_size) { 0 }
  let(:page_number) { 0 }

  describe '#get_facility_clinics' do
    context 'with 1 clinic' do
      it 'returns an array of size 1' do
        VCR.use_cassette('vaos/v2/systems/get_facility_clinics', match_requests_on: %i[method uri]) do
          response = subject.get_facility_clinics(location_id, patient_icn, clinic_ids, clinical_service, page_size, page_number)
          expect(response.size).to eq(4)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/systems/get_facility_clinics_500', match_requests_on: %i[method uri]) do
          expect { subject.get_facility_clinics(location_id, patient_icn, clinic_ids, clinical_service, page_size, page_number) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
