# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::PatientCheckIns', type: :request do
  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in) { CheckIn::PatientCheckIn.build(uuid: id) }

  describe 'POST `create`' do
    before do
      allow(Flipper).to receive(:enabled?)
        .with('check_in_experience_low_authentication_enabled').and_return(true)
      allow_any_instance_of(::V1::Chip::Service).to receive(:check_in).and_return(check_in)
      allow_any_instance_of(::V1::Chip::Service).to receive(:create_check_in).and_return(resp)
    end

    context 'when valid UUID' do
      let(:post_params) { { params: { patient_check_ins: { id: id } } } }
      let(:resp) do
        { 'data' => 'Successful checkin', 'status' => 200 }
      end

      it 'returns a success hash' do
        post '/check_in/v1/patient_check_ins', post_params

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when invalid UUID' do
      let(:post_params) { { params: { patient_check_ins: { id: '1234' } } } }
      let(:resp) do
        { 'data' => { 'error' => true, 'message' => 'Invalid uuid d602d9eb' } }
      end

      it 'returns a data hash with invalid UUID' do
        post '/check_in/v1/patient_check_ins', post_params

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end
  end
end
