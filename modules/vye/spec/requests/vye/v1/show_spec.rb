# frozen_string_literal: true

require 'rails_helper'
require 'json'

RSpec.describe Vye::V1::UserInfosController, type: :request do
  let!(:current_user) { create(:user, :loa3) }

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
      before do
        allow_any_instance_of(described_class).to receive(:load_user_info) do |uic|
          uic.instance_variable_set(:@user_info, nil)
        end
      end

      it 'does not accept the request' do
        get '/vye/v1'
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe 'where current_user is in VYE' do
      let!(:user_info) { build(:vye_user_info, icn: current_user.icn, ssn: current_user.ssn) }

      before do
        allow_any_instance_of(described_class).to receive(:load_user_info) do |uic|
          uic.instance_variable_set(:@user_info, user_info)
        end
        allow(user_info).to receive(:awards).and_return([])
        allow(user_info).to receive(:pending_documents).and_return([])
        allow(user_info).to receive(:verifications).and_return([])
      end

      it 'returns the user_info' do
        get '/vye/v1'
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
