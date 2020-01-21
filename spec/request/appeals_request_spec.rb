# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appeals Status', type: :request do
  include SchemaMatchers

  appeals_endpoint = '/v0/appeals'
  hlr_endpoint = "#{appeals_endpoint}/higher_level_reviews"
  intake_endpoint = "#{appeals_endpoint}/intake_statuses"

  before { sign_in_as(user) }

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1, ssn: '111223333') }

    it 'returns a forbidden error' do
      get appeals_endpoint
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user without a ssn' do
    let(:user) { FactoryBot.create(:user, :loa1, ssn: nil) }

    it 'returns a forbidden error' do
      get appeals_endpoint
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user' do
    let(:user) { FactoryBot.create(:user, :loa3, ssn: '111223333') }

    context 'with a valid response' do
      it 'returns a successful response' do
        VCR.use_cassette('appeals/appeals') do
          get appeals_endpoint
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'with a not authorized response' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('appeals/not_authorized') do
          get appeals_endpoint
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a not found response' do
      it 'returns a 404 and logs an info level message' do
        VCR.use_cassette('appeals/not_found') do
          get appeals_endpoint
          expect(response).to have_http_status(:not_found)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an unprocessible entity response' do
      it 'returns a 422 and logs an info level message' do
        VCR.use_cassette('appeals/invalid_ssn') do
          get appeals_endpoint
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a server error' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('appeals/server_error') do
          get appeals_endpoint
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an invalid JSON body in the response' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('appeals/invalid_body') do
          get appeals_endpoint
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end

    context 'with a null eta' do
      it 'returns a successful response' do
        VCR.use_cassette('appeals/appeals_null_eta') do
          get appeals_endpoint
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'with no alert details due_date' do
      it 'returns a successful response' do
        VCR.use_cassette('appeals/appeals_no_alert_details_due_date') do
          get appeals_endpoint
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    describe 'GET /intake_statuses' do
      context 'with a valid decision review response' do
        it 'returns an intake status response object' do
          VCR.use_cassette('decision_review/200_intake_status') do
            get "#{intake_endpoint}/1234567890"
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('intake_status')
          end
        end
      end

      context 'with a decision response that does not exist' do
        it 'returns a 404 error' do
          VCR.use_cassette('decision_review/404_get_intake_status') do
            get "#{intake_endpoint}/1234"
            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end

    describe 'GET /contestable_issues' do
      context 'with a valid request' do
        it 'returns a valid response' do
          VCR.use_cassette('decision_review/200_contestable_issues') do
            get '/v0/appeals/contestable_issues'
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('contestable_issues')
          end
        end
      end

      context 'with invalid request' do
        it 'returns an invalid response' do
          VCR.use_cassette('decision_review/400_contestable_issues') do
            get '/v0/appeals/contestable_issues'
            expect(response).to have_http_status(:bad_request)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('errors')
          end
        end
      end

      context 'with veteran not found' do
        it 'returns 404' do
          VCR.use_cassette('decision_review/404_contestable_issues') do
            get '/v0/appeals/contestable_issues'
            expect(response).to have_http_status(:not_found)
            expect(response).to match_response_schema('errors')
          end
        end
      end

      context 'bad receipt date' do
        it 'returns 422' do
          VCR.use_cassette('decision_review/422_contestable_issues') do
            get '/v0/appeals/contestable_issues'
            expect(response).to have_http_status(:unprocessable_entity)
            expect(response).to match_response_schema('errors')
          end
        end
      end

      context 'with server error' do
        it 'returns an internal server error' do
          VCR.use_cassette('decision_review/502_contestable_issues') do
            get '/v0/appeals/contestable_issues'
            expect(response).to have_http_status(:bad_gateway)
            expect(response).to match_response_schema('errors')
          end
        end
      end
    end

    describe 'GET /higher_level_reviews' do
      context 'with a valid higher review response' do
        it 'higher level review endpoint returns a successful response' do
          VCR.use_cassette('decision_review/200_review') do
            get "#{hlr_endpoint}/4bc96bee-c6a3-470e-b222-66a47629dc20"
            expect(response).to have_http_status(:ok)
            expect(response).to match_response_schema('higher_level_review')
          end
        end
      end

      context 'with a higher review response id that does not exist' do
        it 'returns a 404 error' do
          VCR.use_cassette('decision_review/404_review') do
            get "#{hlr_endpoint}/1234"
            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end

    describe 'POST /higher_level_reviews' do
      context 'with an accepted response' do
        it 'higher level review endpoint returns a successful response' do
          VCR.use_cassette('decision_review/202_review') do
            request = {
              'data' => {
                'type' => 'HigherLevelReview',
                'attributes' => {
                  'receiptDate' => '2019-07-10',
                  'informalConference' => true,
                  'sameOffice' => false,
                  'legacyOptInApproved' => true,
                  'benefitType' => 'compensation',
                  'veteran' => {
                    'fileNumberOrSsn' => '123456789',
                    'addressLine1' => '123 Street St',
                    'addressLine2' => 'Apt 4',
                    'city' => 'Chicago',
                    'stateProvinceCode' => 'IL',
                    'zipPostalCode' => '60652',
                    'phoneNumber' => '4432924565',
                    'emailAddress' => 'someone@example.com'
                  },
                  'claimant' => {
                    'participantId' => '44444444',
                    'payeeCode' => '10'
                  }
                }
              },
              'included' => [
                {
                  'type' => 'RequestIssue',
                  'attributes' => {
                    'decisionIssueId' => 2
                  }
                }
              ]
            }

            post hlr_endpoint, params: request.to_json
            expect(response).to have_http_status(:accepted)
            expect(response).to match_response_schema('higher_level_review_accepted')
          end
        end
      end

      context 'with a malformed request' do
        it 'higher level review endpoint returns a 400 error' do
          VCR.use_cassette('decision_review/400_review') do
            post hlr_endpoint
            expect(response).to have_http_status(:bad_request)
          end
        end
      end
    end
  end
end
