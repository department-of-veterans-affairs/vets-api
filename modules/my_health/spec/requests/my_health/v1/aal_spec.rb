# frozen_string_literal: true

require 'rails_helper'
require 'mhv/aal/client'
require 'support/mr_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::AALController', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  context 'Unuthorized User' do
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

    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)

      aal_client = AAL::MRClient.new(
        session: {
          user_id:,
          expires_at: 1.hour.from_now,
          token: 'ENC(MA0ECJh1RjEgZFMhAgEQCInE+QaILWiZuYg7kVN8DWTKmiHzcxZzWIDoY2YHQjuWHzusYY4LEb9y)'
        }
      )

      allow(AAL::MRClient).to receive(:new).and_return(aal_client)
      sign_in_as(current_user)
    end

    it 'responds to POST #create' do
      VCR.use_cassette('phr_mgr_client/create_aal_entry') do
        post '/my_health/v1/aal',
             params: {
               activity_type: 'Allergy',
               action: 'View',
               performer_type: 'Self',
               detail_value: nil,
               status: 1,
               product: 'mr'
             },
             as: :json
      end

      expect(response).to have_http_status(:success)
      expect(response.body).to be_a(String)
    end

    it 'fails on form validation' do
      post '/my_health/v1/aal',
           params: {
             activity_type: 'Allergy',
             performer_type: 'Self',
             detail_value: nil,
             status: 3,
             product: 'mr'
           },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to be_a(String)
    end

    it 'fails if product is missing' do
      post '/my_health/v1/aal'

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
  end
end
