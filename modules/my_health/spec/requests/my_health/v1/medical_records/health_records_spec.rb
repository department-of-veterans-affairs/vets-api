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
    bb_client = BB::Client.new(
      session: {
        user_id: 11_375_034,
        expires_at: 1.hour.from_now,
        token: '<SESSION_TOKEN>'
      }
    )

    allow(BB::Client).to receive(:new).and_return(bb_client)
    sign_in_as(current_user)
  end

  context 'Authorized user' do
    describe 'responds to GET #refresh' do
      it 'successfully refreshes' do
        VCR.use_cassette('bb_client/gets_a_list_of_extract_statuses') do
          get '/my_health/v1/health_records/refresh'
          expect(response).to be_successful
          expect(response.parsed_body['data'][0]['type']).to eq('extract_status')
        end
      end
    end

    # describe 'responds to GET #eligible_data_classes' do
    #   it 'successfully retrieves eligible data classes' do
    #     # TODO: this is not used anywhere else, is it correct? Because the serializer blows up.
    #     VCR.use_cassette('bb_client/gets_a_list_of_eligible_data_classes') do
    #       get '/my_health/v1/health_records/eligible_data_classes'
    #       expect(response).to be_successful
    #       expect(response.parsed_body['data']).to be_an(Array)
    #     end
    #   end
    # end

    describe 'responds to GET #status' do
      it 'successfully' do
        VCR.use_cassette('bb_client/gets_vhie_sharing_status') do
          get '/my_health/v1/health_records/sharing/status'
        end
        expect(response).to be_successful
      end
    end

    describe 'responds to POST #create' do
      let(:data_classes) do
        %w[prescriptions medications allergies]
      end
      let(:params) { { from_date: '2020-01-01', to_date: '2020-12-31', data_classes: } }

      it 'successfully' do
        VCR.use_cassette('bb_client/generates_a_report') do
          post '/my_health/v1/health_records', params:
        end
        expect(response).to be_successful
      end
    end

    describe 'responds to POST #optin' do
      it 'successfully' do
        VCR.use_cassette('mr_client/post_opt_in') do
          post '/my_health/v1/health_records/sharing/optin'
        end

        expect(response).to be_successful
      end

      it 'with an error' do
        VCR.use_cassette('mr_client/post_opt_in_error') do
          post '/my_health/v1/health_records/sharing/optin'
        end

        expect(response).to have_http_status(:bad_request)
      end
    end

    describe 'responds to POST #optout' do
      it 'successfully' do
        VCR.use_cassette('mr_client/post_opt_out') do
          post '/my_health/v1/health_records/sharing/optout'
        end

        expect(response).to be_successful
      end

      it 'with an error' do
        VCR.use_cassette('mr_client/post_opt_out_error') do
          post '/my_health/v1/health_records/sharing/optout'
        end

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
