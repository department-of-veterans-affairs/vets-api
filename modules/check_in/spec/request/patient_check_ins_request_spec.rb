# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PatientCheckIns', type: :request do
  let(:faraday_response) { Faraday::Response.new }

  describe 'GET `show`' do
    Timecop.freeze(Time.zone.now)

    let(:resp) do
      {
        'data' => {
          'uuid' => '123aBc',
          'appointment_time' => Time.zone.now.to_s,
          'facility_name' => 'Acme VA',
          'clinic_name' => 'Green Team Clinic1',
          'clinic_phone' => '555-555-5555'
        }
      }
    end

    before do
      allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
      allow_any_instance_of(ChipApi::Service).to receive(:get_check_in).with('123aBc').and_return(resp)
    end

    it 'returns a data hash' do
      get '/check_in/v0/patient_check_ins/123aBc'

      expect(JSON.parse(response.body)).to eq(resp)
    end

    Timecop.return
  end

  describe 'POST `create`' do
    let(:post_params) { { params: { patient_check_ins: { id: '123aBc' } } } }
    let(:resp) do
      { 'data' => 'Successful checkin', 'status' => 200 }
    end

    before do
      allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
      allow_any_instance_of(ChipApi::Service).to receive(:create_check_in).with('123aBc').and_return(resp)
    end

    it 'returns a success hash' do
      post '/check_in/v0/patient_check_ins', post_params

      expect(JSON.parse(response.body)).to eq(resp)
    end
  end
end
