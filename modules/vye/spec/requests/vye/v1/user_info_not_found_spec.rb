# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe 'Vye::V1 UserInfo Not Found', type: :request do
  describe 'GET /vye/v1 when user_info is not found' do
    let!(:current_user) { create(:user, :accountable) }

    before do
      allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
      Flipper.enable :vye_request_allowed
    end

    context 'when user profile exists but has no active user_info' do
      let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }

      before do
        # Ensure user_profile exists but has no active_user_info
        expect(user_profile.active_user_info).to be_nil
      end

      it 'returns a 404 not found status' do
        get '/vye/v1'
        expect(response).to have_http_status(:not_found)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to have_key('errors')
        expect(parsed_response['errors']).to be_an(Array)
        expect(parsed_response['errors'].first['title']).to eq('Resource not found')
        expect(parsed_response['errors'].first['detail']).to include('No active VYE user information found')
        expect(parsed_response['errors'].first['status']).to eq('404')
      end
    end

    context 'when user profile does not exist' do
      it 'returns a 404 not found status' do
        get '/vye/v1'
        expect(response).to have_http_status(:not_found)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response).to have_key('errors')
        expect(parsed_response['errors']).to be_an(Array)
        expect(parsed_response['errors'].first['title']).to eq('Resource not found')
        expect(parsed_response['errors'].first['detail']).to include('No active VYE user information found')
        expect(parsed_response['errors'].first['status']).to eq('404')
      end
    end
  end
end
