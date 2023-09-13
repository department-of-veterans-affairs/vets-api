# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Avs', type: :request do
  before do
    sign_in_as(current_user)
  end

  describe 'GET `index`' do
    let(:current_user) { build(:user, :loa3, icn: '123498767V234859') }

    it 'returns error when stationNo is not given' do
      get '/avs/v0/avs/search?stationNo=&appointmentIen=123456'
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error when appointmentIen is not given' do
      get '/avs/v0/avs/search?stationNo=500&appointmentIen='
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error when stationNo does not have the correct format' do
      get '/avs/v0/avs/search?stationNo=a5c&appointmentIen=123456'
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error when appointmentIen does not have the correct format' do
      get '/avs/v0/avs/search?stationNo=500&appointmentIen=123abc'
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns empty response found when AVS not found for appointment' do
      VCR.use_cassette('avs/search/empty') do
        get '/avs/v0/avs/search?stationNo=500&appointmentIen=10000'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({})
      end
    end

    it 'returns 401 when ICN does not match' do
      VCR.use_cassette('avs/search/unauthorized') do
        get '/avs/v0/avs/search?stationNo=500&appointmentIen=9876543'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'returns 200 when AVS found for appointment' do
      VCR.use_cassette('avs/search/9876543') do
        get '/avs/v0/avs/search?stationNo=500&appointmentIen=9876543'
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          {
            'path' => '/my-health/medical-records/care-summaries/avs/9A7AF40B2BC2471EA116891839113252'
          }
        )
      end
    end
  end

  describe 'GET `show`' do
    icn = '123498767V234859'
    let(:current_user) { build(:user, :loa3, icn:) }

    it 'returns error when sid format is incorrect' do
      get '/avs/v0/avs/1234567890'
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns empty response found when AVS not found for sid' do
      VCR.use_cassette('avs/show/not_found') do
        get '/avs/v0/avs/9A7AF40B2BC2471EA116891839113253'
        expect(response).to have_http_status(:not_found)
      end
    end

    it 'returns 401 when ICN does not match' do
      VCR.use_cassette('avs/show/unauthorized') do
        get '/avs/v0/avs/9A7AF40B2BC2471EA116891839113252'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it 'returns 200 when AVS found for appointment' do
      sid = '9A7AF40B2BC2471EA116891839113252'
      VCR.use_cassette("avs/show/#{sid}") do
        get "/avs/v0/avs/#{sid}"
        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed['data']['id']).to eq(sid)
      end
    end
  end
end
