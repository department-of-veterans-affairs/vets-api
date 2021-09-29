# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::SessionsController', type: :request do
  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?)
      .with('check_in_experience_multiple_appointment_support').and_return(true)

    Rails.cache.clear
  end

  describe 'GET `show`' do
    context 'when invalid uuid' do
      let(:invalid_uuid) { 'invalid_uuid' }
      let(:resp) do
        {
          'body' => {
            'error' => true,
            'message' => 'Invalid uuid, last4 or last name!'
          },
          'status' => 400
        }
      end

      it 'returns an error response' do
        get "/check_in/v2/sessions/#{invalid_uuid}"

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when token not present in session cookie or cache' do
      let(:uuid) { Faker::Internet.uuid }
      let(:resp) do
        {
          'permissions' => 'read.none',
          'status' => 'success',
          'uuid' => uuid
        }
      end

      it 'returns read.none permissions' do
        get check_in.v2_session_path(uuid)

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when token present' do
      let(:uuid) { Faker::Internet.uuid }
      let(:key) { "check_in_lorota_v2_#{uuid}_read.full" }
      let(:resp) do
        {
          'permissions' => 'read.full',
          'status' => 'success',
          'uuid' => uuid
        }
      end

      it 'returns read.full permissions' do
        allow_any_instance_of(CheckIn::V2::Session).to receive(:redis_session_prefix).and_return('check_in_lorota_v2')
        allow_any_instance_of(CheckIn::V2::Session).to receive(:jwt).and_return('jwt-123-1bc')

        Rails.cache.write(key, 'jwt-123-1bc', namespace: 'check-in-lorota-v2-cache')

        get "/check_in/v2/sessions/#{uuid}"

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end
  end

  describe 'POST `create`' do
    it 'returns not implemented' do
      post check_in.v2_sessions_path, params: {}

      expect(response.status).to eq(501)
    end
  end
end
