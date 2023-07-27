# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/auth/client_credentials/service'
require 'lighthouse/service_exception'
require 'disability_compensation/factories/api_provider_factory'

RSpec.describe 'Disability compensation form' do
  include SchemaMatchers

  let(:user) { build(:disabilities_compensation_user) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:headers_with_camel) { headers.merge('X-Key-Inflection' => 'camel') }
  let(:feature_toggle_rated_disabilities) { 'disability_compensation_lighthouse_rated_disabilities_provider' }

  before do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT)
    sign_in_as(user)
  end

  describe 'Get /v0/disability_compensation_form/rated_disabilities' do
    context 'Lighthouse api provider' do
      before do
        Flipper.enable(feature_toggle_rated_disabilities)
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
      end

      context 'with a valid 200 lighthouse response' do
        it 'matches the rated disabilities schema' do
          VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
            get('/v0/disability_compensation_form/rated_disabilities', params: nil, headers:)
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('rated_disabilities')
          end
        end

        it 'matches the rated disabilities schema when camel-inflected' do
          VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
            get '/v0/disability_compensation_form/rated_disabilities', params: nil, headers: headers_with_camel
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('rated_disabilities')
          end
        end
      end

      context 'error handling tests' do
        Lighthouse::ServiceException::ERROR_MAP.each do |status, _error_class|
          error_status = status.to_s.to_i
          cassette_path = "lighthouse/veteran_verification/disability_rating/#{status == :'404' ? '404_ICN' : status}" \
                          '_response'
          it "returns #{status} response" do
            expect(test_error(
                     cassette_path,
                     error_status,
                     headers
                   )).to be(true)
          end

          it "returns a #{status} response with camel-inflection" do
            expect(test_error(
                     cassette_path,
                     error_status,
                     headers_with_camel
                   )).to be(true)
          end
        end

        def test_error(cassette_path, status, headers)
          VCR.use_cassette(cassette_path) do
            get('/v0/disability_compensation_form/rated_disabilities', params: nil, headers:)
            expect(response).to have_http_status(status)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end
      end
    end

    context 'EVSS api provider' do
      before do
        Flipper.disable(feature_toggle_rated_disabilities)
      end

      context 'with a valid 200 evss response' do
        it 'matches the rated disabilities schema' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
            get('/v0/disability_compensation_form/rated_disabilities', params: nil, headers:)
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('rated_disabilities')
          end
        end

        it 'matches the rated disabilities schema when camel-inflected' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities') do
            get '/v0/disability_compensation_form/rated_disabilities', params: nil, headers: headers_with_camel
            expect(response).to have_http_status(:ok)
            expect(response).to match_camelized_response_schema('rated_disabilities')
          end
        end
      end

      context 'with a 500 response' do
        it 'returns a bad gateway response' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_500') do
            get('/v0/disability_compensation_form/rated_disabilities', params: nil, headers:)
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end

        it 'returns a bad gateway response with camel-inflection' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_500') do
            get '/v0/disability_compensation_form/rated_disabilities', params: nil, headers: headers_with_camel
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_camelized_response_schema('evss_errors', strict: false)
          end
        end
      end

      context 'with a 401 response' do
        it 'returns a bad gateway response' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_401') do
            get('/v0/disability_compensation_form/submit_all_claim', params: nil, headers:)
            expect(response).to have_http_status(:not_found)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end

        it 'returns a bad gateway response with camel-inflection' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_401') do
            get '/v0/disability_compensation_form/submit_all_claim', params: nil, headers: headers_with_camel
            expect(response).to have_http_status(:not_found)
            expect(response).to match_camelized_response_schema('evss_errors', strict: false)
          end
        end
      end

      context 'with a 403 unauthorized response' do
        it 'returns a not authorized response' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_403') do
            get('/v0/disability_compensation_form/rated_disabilities', params: nil, headers:)
            expect(response).to have_http_status(:forbidden)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end

        it 'returns a not authorized response with camel-inflection' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_403') do
            get '/v0/disability_compensation_form/rated_disabilities', params: nil, headers: headers_with_camel
            expect(response).to have_http_status(:forbidden)
            expect(response).to match_camelized_response_schema('evss_errors', strict: false)
          end
        end
      end

      context 'with a generic 400 response' do
        it 'returns a bad request response' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_400') do
            get('/v0/disability_compensation_form/rated_disabilities', params: nil, headers:)
            expect(response).to have_http_status(:bad_request)
            expect(response).to match_response_schema('evss_errors', strict: false)
          end
        end

        it 'returns a bad request response with camel-inflection' do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_400') do
            get '/v0/disability_compensation_form/rated_disabilities', params: nil, headers: headers_with_camel
            expect(response).to have_http_status(:bad_request)
            expect(response).to match_camelized_response_schema('evss_errors', strict: false)
          end
        end
      end
    end
  end

  describe 'Post /v0/disability_compensation_form/suggested_conditions/:name_part' do
    before do
      create(:disability_contention_arrhythmia)
      create(:disability_contention_arteriosclerosis)
      create(:disability_contention_arthritis)
    end

    let(:conditions) { JSON.parse(response.body)['data'] }

    it 'returns matching conditions', :aggregate_failures do
      get('/v0/disability_compensation_form/suggested_conditions?name_part=art', params: nil, headers:)
      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('suggested_conditions')
      expect(conditions.count).to eq 3
    end

    it 'returns matching conditions with camel-inflection', :aggregate_failures do
      get '/v0/disability_compensation_form/suggested_conditions?name_part=art',
          params: nil,
          headers: headers_with_camel

      expect(response).to have_http_status(:ok)
      expect(response).to match_camelized_response_schema('suggested_conditions')
      expect(conditions.count).to eq 3
    end

    it 'returns an empty array when no conditions match', :aggregate_failures do
      get('/v0/disability_compensation_form/suggested_conditions?name_part=xyz', params: nil, headers:)
      expect(response).to have_http_status(:ok)
      expect(conditions.count).to eq 0
    end

    it 'returns a 500 when name_part is missing' do
      get('/v0/disability_compensation_form/suggested_conditions', params: nil, headers:)
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'Post /v0/disability_compensation_form/submit_all_claim' do
    before do
      VCR.insert_cassette('emis/get_military_service_episodes/valid')
      VCR.insert_cassette('evss/ppiu/payment_information')
      VCR.insert_cassette('evss/intent_to_file/active_compensation')
    end

    after do
      VCR.eject_cassette('emis/get_military_service_episodes/valid')
      VCR.eject_cassette('evss/ppiu/payment_information')
      VCR.eject_cassette('evss/intent_to_file/active_compensation')
    end

    context 'with a valid 200 evss response' do
      let(:jid) { "JID-#{SecureRandom.base64}" }

      before do
        allow(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim).to receive(:perform_async).and_return(jid)
        create(:in_progress_form, form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: user.uuid)
      end

      context 'with an `all claims` claim' do
        let(:all_claims_form) { File.read 'spec/support/disability_compensation_form/all_claims_fe_submission.json' }

        it 'matches the rated disabilites schema' do
          post('/v0/disability_compensation_form/submit_all_claim', params: all_claims_form, headers:)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('submit_disability_form')
        end

        it 'matches the rated disabilites schema with camel-inflection' do
          post '/v0/disability_compensation_form/submit_all_claim', params: all_claims_form, headers: headers_with_camel
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('submit_disability_form')
        end

        it 'starts the submit job' do
          expect(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim).to receive(:perform_async).once
          post '/v0/disability_compensation_form/submit_all_claim', params: all_claims_form, headers:
        end
      end

      context 'with an `bdd` claim' do
        let(:bdd_form) { File.read 'spec/support/disability_compensation_form/bdd_fe_submission.json' }

        it 'matches the rated disabilites schema' do
          post('/v0/disability_compensation_form/submit_all_claim', params: bdd_form, headers:)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('submit_disability_form')
        end

        it 'matches the rated disabilites schema with camel-inflection' do
          post '/v0/disability_compensation_form/submit_all_claim', params: bdd_form, headers: headers_with_camel
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('submit_disability_form')
        end
      end
    end

    context 'with invalid json body' do
      it 'returns a 422' do
        post('/v0/disability_compensation_form/submit_all_claim', params: { 'form526' => nil }.to_json, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'Get /v0/disability_compensation_form/submission_status' do
    context 'with a success status' do
      let(:submission) { create(:form526_submission, submitted_claim_id: 61_234_567) }
      let(:job_status) { create(:form526_job_status, form526_submission_id: submission.id) }
      let!(:ancillary_job_status) do
        create(:form526_job_status,
               form526_submission_id: submission.id,
               job_class: 'AncillaryForm')
      end

      it 'returns the job status and response', :aggregate_failures do
        get("/v0/disability_compensation_form/submission_status/#{job_status.job_id}", params: nil, headers:)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to match(
          'data' => {
            'id' => '',
            'type' => 'form526_job_statuses',
            'attributes' => {
              'claim_id' => 61_234_567,
              'job_id' => job_status.job_id,
              'submission_id' => submission.id,
              'status' => 'success',
              'ancillary_item_statuses' => [
                a_hash_including('id' => ancillary_job_status.id,
                                 'job_id' => ancillary_job_status.job_id,
                                 'job_class' => 'AncillaryForm',
                                 'status' => 'success',
                                 'error_class' => nil,
                                 'error_message' => nil,
                                 'updated_at' => ancillary_job_status.updated_at.iso8601(3))
              ]
            }
          }
        )
      end
    end

    context 'with a retryable_error status' do
      let(:submission) { create(:form526_submission) }
      let(:job_status) { create(:form526_job_status, :retryable_error, form526_submission_id: submission.id) }

      it 'returns the job status and response', :aggregate_failures do
        get("/v0/disability_compensation_form/submission_status/#{job_status.job_id}", params: nil, headers:)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_deep_attributes(
          'data' => {
            'id' => '',
            'type' => 'form526_job_statuses',
            'attributes' => {
              'claim_id' => nil,
              'job_id' => job_status.job_id,
              'submission_id' => submission.id,
              'status' => 'retryable_error',
              'ancillary_item_statuses' => []
            }
          }
        )
      end
    end

    context 'with a non_retryable_error status' do
      let(:submission) { create(:form526_submission) }
      let(:job_status) { create(:form526_job_status, :non_retryable_error, form526_submission_id: submission.id) }

      it 'returns the job status and response', :aggregate_failures do
        get("/v0/disability_compensation_form/submission_status/#{job_status.job_id}", params: nil, headers:)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_deep_attributes(
          'data' => {
            'id' => '',
            'type' => 'form526_job_statuses',
            'attributes' => {
              'claim_id' => nil,
              'job_id' => job_status.job_id,
              'submission_id' => submission.id,
              'status' => 'non_retryable_error',
              'ancillary_item_statuses' => []
            }
          }
        )
      end
    end

    context 'when no record is found' do
      it 'returns the async submit transaction status and response', :aggregate_failures do
        get('/v0/disability_compensation_form/submission_status/123', params: nil, headers:)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
