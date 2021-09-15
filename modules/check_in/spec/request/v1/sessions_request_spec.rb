# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::SessionsController', type: :request do
  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:basic_check_in) { CheckIn::PatientCheckIn.build(uuid: id) }
  let(:check_in) do
    CheckIn::CheckInWithAuth.build(uuid: id, last4: '1234', last_name: 'Johnson')
  end
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?)
      .with('check_in_experience_low_authentication_enabled').and_return(true)

    Rails.cache.clear
  end

  describe 'GET `show`' do
    context 'when no jwt' do
      let(:resp) do
        {
          'data' => {
            'permissions' => 'read.basic',
            'uuid' => 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            'status' => 'success',
            'jwt' => 'basic-123abc'
          },
          'status' => 200
        }
      end

      it 'returns a basic token' do
        allow_any_instance_of(::V1::Lorota::BasicService).to receive(:get_or_create_token).and_return(resp)

        get "/check_in/v1/sessions/#{id}"

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when jwt' do
      let(:resp) do
        {
          'data' => {
            'permissions' => 'read.full',
            'uuid' => 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            'status' => 'success',
            'jwt' => 'full_jwt_token'
          },
          'status' => 200
        }
      end
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

      it 'returns a full token' do
        allow_any_instance_of(::V1::Lorota::Service).to receive(:get_or_create_token).and_return(data)

        post '/check_in/v1/sessions', session_params
        get "/check_in/v1/sessions/#{id}"

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end
  end

  describe 'POST `create`' do
    context 'when no jwt' do
      let(:resp) do
        {
          'data' => {
            'permissions' => 'read.full',
            'uuid' => 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            'status' => 'success',
            'jwt' => 'full-123abc'
          },
          'status' => 200
        }
      end
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

      it 'returns a basic token' do
        allow_any_instance_of(::V1::Lorota::Service).to receive(:get_or_create_token).and_return(resp)

        post '/check_in/v1/sessions', session_params

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when jwt' do
      let(:resp) do
        {
          'data' => {
            'permissions' => 'read.full',
            'uuid' => 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
            'status' => 'success',
            'jwt' => 'full_jwt_token'
          },
          'status' => 200
        }
      end
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

      it 'returns a full token' do
        allow_any_instance_of(::V1::Lorota::Service).to receive(:get_or_create_token).and_return(resp)
        expect_any_instance_of(::V1::Lorota::Service).to receive(:get_or_create_token).once

        post '/check_in/v1/sessions', session_params

        expect_any_instance_of(::V1::Lorota::Service).to receive(:get_or_create_token).exactly(0).times

        post '/check_in/v1/sessions', session_params

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end
  end
end
