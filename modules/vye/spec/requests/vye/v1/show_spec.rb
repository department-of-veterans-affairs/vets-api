# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe Vye::V1::UserInfosController, type: :request do
  let!(:current_user) { create(:user) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
  end

  describe 'GET /vye/v1 with flag turned off' do
    before do
      Flipper.disable :vye_request_allowed
    end

    it 'does not accept the request' do
      get '/vye/v1'
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET /vye/v1 with flag turned on' do
    before do
      Flipper.enable :vye_request_allowed
    end

    describe 'where current_user is not in VYE' do
      it 'does not accept the request' do
        get '/vye/v1'
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe 'where current_user is in VYE' do
      let!(:user_profile) { FactoryBot.create(:vye_user_profile, icn: current_user.icn) }
      let!(:user_info) { FactoryBot.create(:vye_user_info, user_profile:) }

      it 'returns the user_info' do
        get '/vye/v1'
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
