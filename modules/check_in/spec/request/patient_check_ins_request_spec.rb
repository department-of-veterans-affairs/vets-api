# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PatientCheckIns', type: :request do
  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in) { CheckIn::PatientCheckIn.build(uuid: id) }

  describe 'GET `show`' do
    Timecop.freeze(Time.zone.now)

    context 'when valid UUID' do
      let(:resp) do
        {
          'data' => {
            'uuid' => id,
            'appointment_time' => Time.zone.now.to_s,
            'facility_name' => 'Acme VA',
            'clinic_name' => 'Green Team Clinic1',
            'clinic_phone' => '555-555-5555'
          }
        }
      end

      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
        allow_any_instance_of(ChipApi::Service).to receive(:get_check_in).and_return(resp)
        allow_any_instance_of(ChipApi::Service).to receive(:check_in).and_return(check_in)
      end

      it 'returns a data hash' do
        get '/check_in/v0/patient_check_ins/d602d9eb-9a31-484f-9637-13ab0b507e0d'

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when invalid UUID' do
      let(:resp) do
        { 'data' => { 'error' => true, 'message' => 'Invalid uuid d602d9eb' } }
      end
      let(:invalid_check_in) { CheckIn::PatientCheckIn.build(uuid: 'd602d9eb') }

      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
        allow_any_instance_of(ChipApi::Service).to receive(:get_check_in).and_return(resp)
        allow_any_instance_of(ChipApi::Service).to receive(:check_in).and_return(invalid_check_in)
      end

      it 'returns a data hash with invalid UUID' do
        get '/check_in/v0/patient_check_ins/d602d9eb'

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    Timecop.return
  end

  describe 'POST `create`' do
    before do
      allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
      allow_any_instance_of(ChipApi::Service).to receive(:check_in).and_return(check_in)
      allow_any_instance_of(ChipApi::Service).to receive(:create_check_in).and_return(resp)
    end

    context 'when valid UUID' do
      let(:post_params) { { params: { patient_check_ins: { id: id } } } }
      let(:resp) do
        { 'data' => 'Successful checkin', 'status' => 200 }
      end

      it 'returns a success hash' do
        post '/check_in/v0/patient_check_ins', post_params

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when invalid UUID' do
      let(:post_params) { { params: { patient_check_ins: { id: '1234' } } } }
      let(:resp) do
        { 'data' => { 'error' => true, 'message' => 'Invalid uuid d602d9eb' } }
      end

      it 'returns a data hash with invalid UUID' do
        post '/check_in/v0/patient_check_ins', post_params

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end
  end
end
