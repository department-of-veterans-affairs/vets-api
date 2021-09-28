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
            'message' => "Invalid uuid #{invalid_uuid}"
          },
          'status' => 400
        }
      end

      it 'returns an error response' do
        get check_in.v2_session_path(invalid_uuid)

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when token not present in session cookie or cache' do
      let(:uuid) { Faker::Internet.uuid }
      let(:resp) do
        {
          'data' => {
            'permissions' => 'read.none',
            'uuid' => uuid,
            'status' => 'success'
          }
        }
      end

      it 'returns read.none permissions' do
        get check_in.v2_session_path(uuid)

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
