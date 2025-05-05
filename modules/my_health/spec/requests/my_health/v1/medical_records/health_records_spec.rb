# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'bb/client'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::HealthRecordsController', type: :request do
  include MedicalRecords::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '11375034' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv) }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)

    bb_client = BB::Client.new(
      session: {
        user_id: 11_375_034,
        expires_at: 1.hour.from_now,
        token: 'ENC(MA0ECJh1RjEgZFMhAgEQC4nF/gSOKGSZuYg7kVN8DWTOniDwcBB7XYB2mboEA0Zz2uSiW7tpAgiQ)'
      }
    )

    allow(BB::Client).to receive(:new).and_return(bb_client)
    sign_in_as(current_user)
  end

  context 'Authorized user' do
    before do
      VCR.insert_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                          match_requests_on: %i[method sm_user_ignoring_path_param])
    end

    after do
      VCR.eject_cassette
    end

    it 'responds to POST #optin' do
      VCR.use_cassette('mr_client/post_opt_in') do
        post '/my_health/v1/health_records/sharing/optin'
      end

      puts "response: #{response.inspect}"

      expect(response).to be_successful
      expect(response.body).to be_a(String)
    end
  end
end
