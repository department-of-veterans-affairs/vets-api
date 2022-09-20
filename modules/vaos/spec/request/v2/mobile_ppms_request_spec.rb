# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::ProvidersController, type: :request do
  include SchemaMatchers

  let(:current_user) { build(:user, :jac) }

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'when a valid NPI is provided' do
    it "responds with the provider's information" do
      VCR.use_cassette('vaos/v2/mobile_ppms_service/get_provider_200',
                       match_requests_on: %i[method path query], tag: :force_utf8) do
        get '/vaos/v2/providers/1407938061'
        expect(response).to have_http_status(:ok)
        expect(json_body_for(response)['attributes']['name']).to eq('DEHGHAN, AMIR ')
      end
    end
  end

  describe 'when an invalid request is made' do
    it 'responds with a 400 error' do
      VCR.use_cassette('vaos/v2/mobile_ppms_service/get_provider_400',
                       match_requests_on: %i[method path query], tag: :force_utf8) do
        get '/vaos/v2/providers/489'
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'when a request is made and there is a server error' do
    it 'responds with a 500 error' do
      VCR.use_cassette('vaos/v2/mobile_ppms_service/get_provider_500',
                       match_requests_on: %i[method path query], tag: :force_utf8) do
        get '/vaos/v2/providers/489'
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
