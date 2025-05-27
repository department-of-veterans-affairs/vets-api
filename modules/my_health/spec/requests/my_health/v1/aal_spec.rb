# frozen_string_literal: true

require 'rails_helper'
require 'mhv/aal/client'
require 'support/mr_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::AALController', type: :request do
  context 'Unauthorized user' do
    context 'with no MHV Correlation ID' do
      let(:user_id) { '21207668' }
      let(:current_user) { build(:user) }

      before do
        sign_in_as(current_user)
      end

      it 'returns 403 Forbidden when MHV Correlation ID is missing' do
        post '/my_health/v1/aal'

        expect(current_user.mhv_correlation_id).to be_nil
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['errors'].first['detail']).to eq('You do not have access to the AAL service')
      end
    end
  end

  context 'Authorized User' do
    let(:user_id) { '21207668' }
    let(:current_user) { build(:user, :mhv, mhv_account_type:) }
    let(:mhv_account_type) { 'Premium' }
    let(:valid_params) do
      {
        aal: {
          activity_type: 'Allergy',
          action: 'View',
          performer_type: 'Self',
          detail_value: nil,
          status: 1
        },
        product: 'mr'
      }
    end

    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_enable_aal_integration).and_return(true)

      aal_client = AAL::MRClient.new(
        session: {
          user_id:,
          expires_at: 1.hour.from_now,
          token: '<SESSION_TOKEN>'
        }
      )

      allow(AAL::MRClient).to receive(:new).and_return(aal_client)
      sign_in_as(current_user)
    end

    it 'responds to POST #create' do
      expect_any_instance_of(AAL::MRClient).to receive(:perform)
      VCR.use_cassette('phr_mgr_client/create_aal_entry') do
        post '/my_health/v1/aal', params: valid_params, as: :json
      end

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_a(String)
    end

    it 'fails on form validation' do
      invalid_params = valid_params.dup
      invalid_params[:aal] = invalid_params[:aal].merge(status: 3)

      post '/my_health/v1/aal', params: invalid_params, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to be_a(String)
    end

    it 'fails if product is missing' do
      invalid_params = valid_params.dup
      invalid_params.delete(:product)

      post '/my_health/v1/aal', params: invalid_params, as: :json

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['errors'].first['detail']).to eq('The required parameter "product", is missing')
    end

    it 'fails if product is unknown' do
      post '/my_health/v1/aal', params: { product: 'unknown' }, as: :json

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['errors'].first['detail']).to eq('Unknown product: unknown')
    end

    it 'skips the HTTP call with the flag off' do
      allow(Flipper).to receive(:enabled?).with(:mhv_enable_aal_integration).and_return(false)
      expect_any_instance_of(AAL::MRClient).not_to receive(:perform)

      post '/my_health/v1/aal', params: valid_params, as: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
