# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::V1::DirectDepositChangesController, type: :request do
  let!(:current_user) { create(:user, :loa3) }
  let(:params) { FactoryBot.attributes_for(:vye_direct_deposit_change) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
  end

  describe 'POST /vye/v1/bank_info with flag turned off' do
    before { Flipper.disable :vye_request_allowed }

    it 'will not accept the request' do
      post('/vye/v1/bank_info', params:)
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /vye/v1/bank_info where current_user is not in VYE' do
    it 'will not accept the request' do
      post('/vye/v1/bank_info', params:)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /vye/v1/bank_info where current_user is in VYE' do
    let!(:user_info) { create(:vye_user_info, icn: current_user.icn, ssn: current_user.ssn) }

    it 'creates a new bank info' do
      expect do
        post '/vye/v1/bank_info', params:
      end.to change(Vye::DirectDepositChange, :count).by(1)
    end
  end
end
