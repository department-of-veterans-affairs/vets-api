# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::PatientCheckIns', type: :request do
  let(:id) { Faker::Internet.uuid }
  let(:check_in) { CheckIn::V2::Session.build(data: { uuid: id }, jwt: nil) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?)
      .with('check_in_experience_multiple_appointment_support').and_return(true)
    allow(Flipper).to receive(:enabled?)
      .with(:check_in_experience_demographics_page_enabled).and_return(true)

    Rails.cache.clear
  end

  describe 'GET `show`' do
    context 'when JWT token and Redis entries are absent' do
      let(:resp) do
        {
          'permissions' => 'read.none',
          'status' => 'success',
          'uuid' => id
        }
      end

      it 'returns unauthorized status' do
        get "/check_in/v2/patient_check_ins/#{id}"

        expect(response.status).to eq(401)
      end

      it 'returns read.none permissions' do
        get "/check_in/v2/patient_check_ins/#{id}"

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when JWT token and Redis entries are present' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid: id,
              last4: '5555',
              last_name: 'Johnson'
            }
          }
        }
      end
      let(:key) { "check_in_lorota_v2_#{id}_read.full" }
      let(:resp) do
        {
          'id' => id,
          'payload' => {
            'appointments' => []
          }
        }
      end

      it 'returns a success response' do
        allow_any_instance_of(CheckIn::V2::Session).to receive(:redis_session_prefix).and_return('check_in_lorota_v2')
        allow_any_instance_of(CheckIn::V2::Session).to receive(:jwt).and_return('jwt-123-1bc')
        allow_any_instance_of(::V2::Lorota::Service).to receive(:get_check_in_data).and_return(resp)

        Rails.cache.write(key, 'jwt-123-1bc', namespace: 'check-in-lorota-v2-cache')

        get "/check_in/v2/patient_check_ins/#{id}"

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end
  end

  describe 'POST `create`' do
    before do
      allow_any_instance_of(::V2::Chip::Service).to receive(:check_in).and_return(check_in)
      allow_any_instance_of(::V2::Chip::Service).to receive(:create_check_in).and_return(resp)
      allow_any_instance_of(CheckIn::V2::Session).to receive(:redis_session_prefix).and_return('check_in_lorota_v2')
      allow_any_instance_of(CheckIn::V2::Session).to receive(:jwt).and_return('jwt-123-1bc')
    end

    let(:post_params) { { params: { patient_check_ins: { uuid: id, appointment_ien: '123-abc' } } } }
    let(:session_params) do
      {
        params: {
          session: {
            uuid: id,
            last4: '5555',
            last_name: 'Johnson'
          }
        }
      }
    end
    let(:resp) do
      { 'data' => 'Successful checkin', 'status' => 200 }
    end
    let(:key) { "check_in_lorota_v2_#{id}_read.full" }

    it 'returns a success hash' do
      Rails.cache.write(key, 'jwt-123-1bc', namespace: 'check-in-lorota-v2-cache')

      post '/check_in/v2/sessions', session_params
      post '/check_in/v2/patient_check_ins', post_params

      expect(JSON.parse(response.body)).to eq(resp)
    end
  end
end
