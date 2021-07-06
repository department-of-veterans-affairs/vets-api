# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PatientCheckIns', type: :request do
  let(:faraday_response) { Faraday::Response.new }

  describe 'GET `show`' do
    Timecop.freeze(Time.zone.now)

    let(:resp) do
      {
        ':data' => {
          ':uuid' => '123aBc',
          ':appointment_time' => Time.zone.now.to_s,
          ':facility_name' => 'Acme VA',
          ':clinic_name' => 'Green Team Clinic1',
          ':clinic_phone' => '555-555-5555'
        }
      }
    end

    before do
      allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
      allow_any_instance_of(ChipApi::Request).to receive(:get).with('123aBc').and_return(faraday_response)
    end

    it 'returns an empty response' do
      get '/check_in/v0/patient_check_ins/123aBc?cookie_id=23496jgsdf'

      expect(JSON.parse(response.body)).to eq(resp)
    end

    Timecop.return
  end

  describe 'POST `create`' do
    let(:post_params) { { params: { patient_check_ins: { id: '123aBc' } } } }
    let(:resp) do
      { ':data' => { ':check_in_status' => 'completed' } }
    end

    before do
      allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
      allow_any_instance_of(ChipApi::Request).to receive(:post)
        .with({ 'id' => '123aBc' }).and_return(faraday_response)
    end

    it 'returns a default json payload' do
      post '/check_in/v0/patient_check_ins', post_params

      expect(JSON.parse(response.body)).to eq(resp)
    end
  end
end
