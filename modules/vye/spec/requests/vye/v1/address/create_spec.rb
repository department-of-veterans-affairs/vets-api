# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe 'Vye::V1::Address#create', type: :request do
  let!(:current_user) { create(:user, :accountable) }

  let(:headers) { { 'Content-Type' => 'application/json', 'X-Key-Inflection' => 'camel' } }

  let(:params) do
    attributes_for(:vye_address_change)
      .deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      .slice('veteranName', 'address1', 'address2', 'address3', 'address4', 'city', 'state', 'zipCode')
      .to_json
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
  end

  describe 'POST /vye/v1/address with flag turned off' do
    before do
      Flipper.disable :vye_request_allowed
    end

    it 'does not accept the request' do
      post('/vye/v1/address', params:)
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /vye/v1/address with flag turned on' do
    before do
      Flipper.enable :vye_request_allowed
    end

    describe 'where current_user is not in VYE' do
      it 'does not accept the request' do
        post('/vye/v1/address', params:)
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe 'where current_user is in VYE' do
      let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
      let!(:user_info) { create(:vye_user_info, user_profile:) }

      it 'creates a new address' do
        post('/vye/v1/address', headers:, params:)
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
