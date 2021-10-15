# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::PatientsService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#index' do
    context 'with an patient' do
      it 'returns a patient' do
        VCR.use_cassette('vaos/v2/patients/get_patient_appointment_metadata', match_requests_on: %i[method uri]) do
          response = subject.get_patient_appointment_metadata('primaryCare', '100', 'direct')
          expect(response[:eligible]).to eq(false)

          expect(response[:ineligibility_reasons][0][:coding][0][:code]).to eq('facility-cs-direct-disabled')
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
