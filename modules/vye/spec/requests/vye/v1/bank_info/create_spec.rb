# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe 'Vye::V1::DirectDeposit#create', type: :request do
  let!(:current_user) { create(:user, :accountable) }

  let(:headers) { { 'Content-Type' => 'application/json', 'X-Key-Inflection' => 'camel' } }

  let(:params) do
    attributes_for(:vye_direct_deposit_change)
      .deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      .slice('fullName', 'phone', 'email', 'acctNo', 'acctType', 'routingNo', 'bankName', 'bankPhone')
      .to_json
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(false)
  end

  describe 'where current_user is not in VYE' do
    it 'does not accept the request' do
      post('/vye/v1/bank_info', params:)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'where current_user is in VYE' do
    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:) }

    it 'creates a new bank info' do
      post('/vye/v1/bank_info', headers:, params:)
      expect(response).to have_http_status(:no_content)
    end

    context 'with BDN processing disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(true)
      end

      it 'returns an bad_request response' do
        post('/vye/v1/bank_info', headers:, params:)

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
