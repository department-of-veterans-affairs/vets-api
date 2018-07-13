# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability compensation form', type: :request do
  include SchemaMatchers

  let(:user) { build(:disabilities_compensation_user) }
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'Get /v0/disability_compensation_form/rated_disabilities' do
    context 'with a valid 200 evss response' do
      it 'should match the rated disabilities schema' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('rated_disabilities')
        end
      end
    end

    context 'with a 500 response' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_500') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 403 unauthorized response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_403') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a generic 400 response' do
      it 'should return a bad request response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_400') do
          get '/v0/disability_compensation_form/rated_disabilities', nil, auth_header
          expect(response).to have_http_status(:bad_request)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 401 response' do
      it 'should return a bad gateway response' do
        VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_401') do
          get '/v0/disability_compensation_form/submit', nil, auth_header
          expect(response).to have_http_status(:not_found)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end
  end

  describe 'Get /v0/disability_compensation_form/submit' do
    before(:each) do
      VCR.insert_cassette('emis/get_military_service_episodes/valid')
      VCR.insert_cassette('evss/ppiu/payment_information')
      VCR.insert_cassette('evss/intent_to_file/active_compensation')
    end

    after(:each) do
      VCR.eject_cassette('emis/get_military_service_episodes/valid')
      VCR.eject_cassette('evss/ppiu/payment_information')
      VCR.eject_cassette('evss/intent_to_file/active_compensation')
    end

    context 'with a valid 200 evss response' do
      let(:valid_form_content) { File.read 'spec/support/disability_compensation_form/front_end_submission.json' }
      let(:jid) { "JID-#{SecureRandom.base64}" }

      before(:each) { allow(EVSS::DisabilityCompensationForm::SubmitUploads).to receive(:start).and_return(jid) }

      before do
        create(:in_progress_form, form_id: VA526ez::FORM_ID, user_uuid: user.uuid)
      end

      it 'should match the rated disabilities schema' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          post '/v0/disability_compensation_form/submit', valid_form_content, auth_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('submit_disability_form')
        end
      end

      it 'should start the uploads job' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          expect(EVSS::DisabilityCompensationForm::SubmitUploads).to receive(:start).once
          post '/v0/disability_compensation_form/submit', valid_form_content, auth_header
        end
      end

      context 'with a 500 response' do
        it 'should return a bad gateway response' do
          VCR.use_cassette('evss/disability_compensation_form/submit_500') do
            post '/v0/disability_compensation_form/submit', valid_form_content, auth_header
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end
      end

      context 'with a 403 unauthorized response' do
        it 'should return a not authorized response' do
          VCR.use_cassette('evss/disability_compensation_form/submit_403') do
            post '/v0/disability_compensation_form/submit', valid_form_content, auth_header
            expect(response).to have_http_status(:forbidden)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end
      end

      context 'with a 400 response' do
        let(:validation_array) do
          [
            {
              'key' => 'form526.serviceInformation.ConfinementPastActiveDutyDate',
              'severity' => 'ERROR',
              'text' => 'The confinement start date is too far in the past'
            },
            {
              'key' => 'form526.serviceInformation.ConfinementWithInServicePeriod',
              'severity' => 'ERROR',
              'text' => 'Your period of confinement must be within a single period of service'
            },
            {
              'key' => 'form526.veteran.homelessness.pointOfContact.pointOfContactName.Pattern',
              'severity' => 'ERROR',
              'text' => 'must match "([a-zA-Z0-9-/]+( ?))*$"'
            }
          ]
        end

        it 'should return a unprocessable_entity response' do
          VCR.use_cassette('evss/disability_compensation_form/submit_400') do
            post '/v0/disability_compensation_form/submit', valid_form_content, auth_header
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response).to match_response_schema('evss_errors', strict: false)
            meta = JSON.parse(response.body).dig('errors').first.dig('meta', 'messages')
            expect(meta).to match_array(validation_array)
          end
        end
      end

      context 'with a 401 response' do
        it 'should return a bad gateway response' do
          VCR.use_cassette('evss/disability_compensation_form/submit_401') do
            post '/v0/disability_compensation_form/submit', valid_form_content, auth_header
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end
      end
    end
  end
end
