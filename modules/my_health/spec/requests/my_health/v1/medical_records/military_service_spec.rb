# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/phr_mgr/client'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::MedicalRecords::MilitaryServiceController', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  context 'Unuthorized User' do
    context 'with no EDIPI' do
      let(:user_id) { '21207668' }
      let(:current_user) { build(:user) }

      before do
        sign_in_as(current_user)
      end

      it 'returns 400 Bad Request when EDIPI is missing' do
        sign_in_as(current_user)

        get '/my_health/v1/medical_records/military_service'

        expect(current_user.icn).not_to be_nil
        expect(current_user.edipi).to be_nil
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        puts "json: #{json}"
        expect(json['error']).to eq('No EDIPI found for the current user')
      end
    end

    context 'with no ICN' do
      let(:user_id) { '21207668' }
      let(:current_user) { build(:user, :mhv, mhv_account_type:, edipi: '1234567890', icn: nil) }
      let(:mhv_account_type) { 'Premium' }

      before do
        sign_in_as(current_user)
      end

      it 'returns 403 Forbidden when ICN is missing' do
        sign_in_as(current_user)

        get '/my_health/v1/medical_records/military_service'

        expect(current_user.icn).to be_nil
        expect(current_user.edipi).not_to be_nil
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['errors'].first['detail']).to eq('You do not have access to military service information')
      end
    end
  end

  context 'Authorized User' do
    let(:user_id) { '21207668' }
    let(:current_user) { build(:user, :mhv, mhv_account_type:, edipi: '1234567890') }
    let(:mhv_account_type) { 'Premium' }

    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)

      phr_mgr_client = PHRMgr::Client.new(
        session: {
          user_id: 11_375_034,
          icn: '1000000000V000000',
          patient_id: '11382904',
          expires_at: 1.hour.from_now,
          token: '<SESSION_TOKEN>'
        }
      )

      allow(PHRMgr::Client).to receive(:new).and_return(phr_mgr_client)
      sign_in_as(current_user)
    end

    it 'responds to GET #index' do
      VCR.use_cassette('phr_mgr_client/get_military_service') do
        get '/my_health/v1/medical_records/military_service'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
    end
  end
end
