# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'

RSpec.describe MyHealth::V1::MedicalRecords::CcdController, type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:user_id) { 11_375_034 }
  let(:va_patient) { true }
  let(:current_user) do
    build(:user, :mhv, va_patient:, mhv_account_type:, icn: '1012740022V620959', last_name: 'TESTUSER')
  end
  let(:aal_client) { instance_spy(AAL::MRClient) }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_enable_aal_integration).and_return(true)

    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(AAL::MRClient).to receive(:new).and_return(aal_client)

    bb_internal_client = BBInternal::Client.new(
      session: {
        user_id:,
        icn: '1012740022V620959',
        patient_id: '11382904',
        expires_at: 1.hour.from_now,
        token: '<SESSION_TOKEN>'
      }
    )
    allow(BBInternal::Client).to receive(:new).and_return(bb_internal_client)

    sign_in_as(current_user)
  end

  context 'Authorized user' do
    let(:mhv_account_type) { 'Premium' }

    before do
      VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                          match_requests_on: %i[method sm_user_ignoring_path_param])
    end

    after do
      VCR.eject_cassette
    end

    describe 'GET #generate' do
      it 'succeeds' do
        VCR.use_cassette('mr_client/get_ccd_generate') do
          get '/my_health/v1/medical_records/ccd/generate'
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns 500 and logs an AAL error when API call fails' do
        allow_any_instance_of(BBInternal::Client)
          .to receive(:get_generate_ccd)
          .and_raise(StandardError.new('ccd generate failed'))

        get '/my_health/v1/medical_records/ccd/generate'

        expect(response).to have_http_status(:internal_server_error)
        expect_aal_download_error_logged
      end
    end

    describe 'GET #download' do
      it 'succeeds' do
        VCR.use_cassette('mr_client/get_ccd_download') do
          get '/my_health/v1/medical_records/ccd/download?date=2025-05-06T09:26:08.000-0400'
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns 500 and logs an AAL error when API call fails' do
        allow_any_instance_of(BBInternal::Client)
          .to receive(:get_download_ccd)
          .and_raise(StandardError.new('ccd download failed'))

        VCR.use_cassette('mr_client/get_ccd_download_error') do
          get '/my_health/v1/medical_records/ccd/download?date=2025-05-06T09:26:08.000-0400'
        end

        expect(response).to have_http_status(:internal_server_error)
        expect_aal_download_error_logged
      end

      it 'returns 400 and logs an AAL error when date is missing' do
        allow_any_instance_of(BBInternal::Client)
          .to receive(:get_download_ccd)
          .and_raise(StandardError.new('ccd download failed'))

        VCR.use_cassette('mr_client/get_ccd_download_missing_date_param') do
          get '/my_health/v1/medical_records/ccd/download'
        end

        expect(response).to have_http_status(:bad_request)
        expect_aal_download_error_logged
      end
    end

    def expect_aal_download_error_logged
      expect(aal_client).to have_received(:create_aal).with(
        hash_including(
          activity_type: 'Download',
          action: 'Download My VA Health Summary',
          performer_type: 'Self',
          status: 0
        ),
        false,
        anything # unique session ID could be different things depending on how it's implemented
      )
    end
  end
end
