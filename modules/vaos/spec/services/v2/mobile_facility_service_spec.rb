# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::MobileFacilityService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#configuration' do
    context 'with a facility id' do
      it 'returns a configuration' do
        VCR.use_cassette('vaos/v2/mobile_facility/get_scheduling_configurations', record: :new_episodes) do
          response = subject.get_scheduling_configurations(%w('489'), false)

        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/patients/get_patient_appointment_metadata_500', match_requests_on: %i[method uri]) do
          expect { subject.get_patient_appointment_metadata('primaryCare', '100', 'direct') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
