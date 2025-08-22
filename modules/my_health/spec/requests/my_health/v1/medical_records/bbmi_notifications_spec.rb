# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/bb_internal/client'


RSpec.describe 'MyHealth::V1::BbmiNotificationController', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '11375034' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv) }

    before do
    bb_internal_client = BBInternal::Client.new(
      session: {
        user_id: 11_375_034,
        icn: '1000000000V000000',
        patient_id: '11382904',
        expires_at: 1.hour.from_now,
        token: 'SESSION_TOKEN'
      }
    )

    allow(MedicalRecords::Client).to receive(:new).and_return(authenticated_client)
    allow(BBInternal::Client).to receive(:new).and_return(bb_internal_client)
    sign_in_as(current_user)
    VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                        match_requests_on: %i[method sm_user_ignoring_path_param])
  end

    describe 'responds to GET #status' do
      it 'successfully' do
        VCR.use_cassette('mr_client/bb_internal/get_bbmi_notification_setting') do
          get '/my_health/v1/medical_records/bbmi_notification/status'
        end
        expect(response).to be_successful
        expect(response.parsed_body['flag']).to eq(true)
      end
    end
  end
