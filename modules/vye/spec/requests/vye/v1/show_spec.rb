# frozen_string_literal: true

require 'rails_helper'
require 'json'

RSpec.describe Vye::V1::UserInfosController, type: :request do
  describe 'GET /v1' do
    let!(:current_user) { create(:user, :loa3) }
    let!(:user_info) { create(:vye_user_info, icn: current_user.icn, ssn: current_user.ssn) }
    let!(:award) { create(:vye_award, user_info:) }
    let!(:pending_document) { create(:vye_pending_document, ssn: user_info.ssn) }
    let!(:verification) { create(:vye_verification, user_info:, award:) }

    before do
      allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    end

    context 'when master switch is disabled' do
      before { Flipper.disable :vye_request_allowed }

      it 'will not accept the request' do
        get '/vye/v1'
        expect(response).to have_http_status(:bad_request)
      end
    end

    it 'returns the user_info' do
      get '/vye/v1'
      expect(response).to have_http_status(:ok)
    end
  end
end
