# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::PatientCheckIns', type: :request do
  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in) { CheckIn::PatientCheckIn.build(uuid: id) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe 'POST `create`' do
    before do
      allow(Flipper).to receive(:enabled?)
        .with('check_in_experience_low_authentication_enabled').and_return(true)
      allow_any_instance_of(::V1::Chip::Service).to receive(:check_in).and_return(check_in)
      allow_any_instance_of(::V1::Chip::Service).to receive(:create_check_in).and_return(resp)
    end

    context 'when valid UUID' do
      let(:post_params) { { params: { patient_check_ins: { id: id } } } }
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
      let(:data) do
        {
          data: {
            jwt: 'full_jwt_token'
          }
        }
      end
      let(:resp) do
        { 'data' => 'Successful checkin', 'status' => 200 }
      end

      it 'returns a success hash' do
        allow_any_instance_of(::V1::Lorota::Service).to receive(:get_or_create_token).and_return(data)

        post '/check_in/v1/sessions', session_params
        post '/check_in/v1/patient_check_ins', post_params

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when invalid UUID' do
      let(:post_params) { { params: { patient_check_ins: { id: '1234' } } } }
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
      let(:data) do
        {
          data: {
            jwt: 'full_jwt_token'
          }
        }
      end
      let(:resp) do
        { 'data' => { 'error' => true, 'message' => 'Check-in failed' }, 'status' => 403 }
      end

      it 'returns a data hash with invalid UUID' do
        allow_any_instance_of(::V1::Lorota::Service).to receive(:get_or_create_token).and_return(data)

        post '/check_in/v1/sessions', session_params
        post '/check_in/v1/patient_check_ins', post_params

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end
  end

  describe 'GET `show`' do
    before do
      allow(Flipper).to receive(:enabled?)
        .with('check_in_experience_low_authentication_enabled').and_return(true)
      allow_any_instance_of(::V1::Chip::Service).to receive(:check_in).and_return(check_in)
    end

    context 'when no jwt' do
      let(:resp) do
        {
          'id' => id,
          'scope' => 'read.basic',
          'payload' => {
            'full' => 'false'
          }
        }
      end

      it 'returns the partial appointment details' do
        allow_any_instance_of(::V1::Lorota::BasicService).to receive(:get_check_in).and_return(resp)

        get "/check_in/v1/patient_check_ins/#{id}"

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when jwt' do
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
      let(:data) do
        {
          data: {
            jwt: 'full_jwt_token'
          }
        }
      end
      let(:resp) do
        {
          'id' => id,
          'scope' => 'read.full',
          'payload' => {
            'full' => 'true'
          }
        }
      end

      it 'returns the full appointment details' do
        allow_any_instance_of(::V1::Lorota::Service).to receive(:get_or_create_token).and_return(data)
        allow_any_instance_of(::V1::Lorota::Service).to receive(:get_check_in).and_return(resp)

        post '/check_in/v1/sessions', session_params
        get "/check_in/v1/patient_check_ins/#{id}"

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end
  end
end
