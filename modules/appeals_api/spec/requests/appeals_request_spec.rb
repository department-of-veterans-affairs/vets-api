# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Claim Appeals API endpoint', type: :request do
  include SchemaMatchers

  appeals_endpoint = '/services/appeals/v0/appeals'
  hlr_endpoint = "#{appeals_endpoint}/higher_level_reviews"
  intake_endpoint = "#{appeals_endpoint}/intake_statuses"

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
          expect(response).to match_response_schema('errors')
        end
      end
    end
  end

  context 'with the X-VA-SSN and X-VA-User header supplied ' do
    let(:user) { FactoryBot.create(:user, :loa3) }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
    let(:user_headers) do
      {
        'X-VA-SSN' => '111223333',
        'X-VA-First-Name' => 'Test',
        'X-VA-Last-Name' => 'Test',
        'X-VA-EDIPI' => 'Test',
        'X-VA-Birth-Date' => '1985-01-01',
        'X-Consumer-Username' => 'TestConsumer',
        'X-VA-User' => 'adhoc.test.user'
      }
    end

    before do
      @verifier_stub = instance_double('EVSS::PowerOfAttorneyVerifier')
      allow(EVSS::PowerOfAttorneyVerifier).to receive(:new) { @verifier_stub }
      allow(@verifier_stub).to receive(:verify)
    end

    it 'returns a successful response' do
      VCR.use_cassette('appeals/appeals') do
        get appeals_endpoint, params: nil, headers: user_headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('appeals')
      end
    end

    it 'logs details about the request' do
      VCR.use_cassette('appeals/appeals') do
        allow(Rails.logger).to receive(:info)
        get appeals_endpoint, params: nil, headers: user_headers

        hash = Digest::SHA2.hexdigest '111223333'
        expect(Rails.logger).to have_received(:info).with('Caseflow Request',
                                                          'va_user' => 'adhoc.test.user',
                                                          'lookup_identifier' => hash)
        expect(Rails.logger).to have_received(:info).with('Caseflow Response',
                                                          'va_user' => 'adhoc.test.user',
                                                          'first_appeal_id' => '1196201',
                                                          'appeal_count' => 3)
      end
    end
  end

  context 'with an empty response' do
    let(:user) { FactoryBot.create(:user, :loa3) }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
    let(:user_headers) do
      {
        'X-VA-SSN' => '111223333',
        'X-Consumer-Username' => 'TestConsumer',
        'X-VA-User' => 'adhoc.test.user'
      }
    end

    before do
      @verifier_stub = instance_double('EVSS::PowerOfAttorneyVerifier')
      allow(EVSS::PowerOfAttorneyVerifier).to receive(:new) { @verifier_stub }
      allow(@verifier_stub).to receive(:verify)
    end

    it 'returns a successful response' do
      VCR.use_cassette('appeals/appeals_empty') do
        get appeals_endpoint, params: nil, headers: user_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('appeals')
      end
    end

    it 'logs appropriately' do
      VCR.use_cassette('appeals/appeals_empty') do
        allow(Rails.logger).to receive(:info)
        get appeals_endpoint, params: nil, headers: user_headers

        hash = Digest::SHA2.hexdigest '111223333'
        expect(Rails.logger).to have_received(:info).with('Caseflow Request',
                                                          'va_user' => 'adhoc.test.user',
                                                          'lookup_identifier' => hash)
        expect(Rails.logger).to have_received(:info).with('Caseflow Response',
                                                          'va_user' => 'adhoc.test.user',
                                                          'first_appeal_id' => nil,
                                                          'appeal_count' => 0)
      end
    end
  end

  context 'without the X-VA-User header supplied' do
    it 'returns a successful response' do
      VCR.use_cassette('appeals/appeals') do
        get appeals_endpoint,
            params: nil,
            headers: { 'X-VA-SSN' => '111223333',
                       'X-Consumer-Username' => 'TestConsumer' }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'without the X-VA-SSN header supplied' do
    it 'returns a successful response' do
      VCR.use_cassette('appeals/appeals') do
        get appeals_endpoint,
            params: nil,
            headers: { 'X-Consumer-Username' => 'TestConsumer',
                       'X-VA-User' => 'adhoc.test.user' }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  context 'when requesting the healthcheck route' do
    it 'returns a successful response' do
      VCR.use_cassette('appeals/health-check') do
        get '/services/appeals/v0/healthcheck'
        expect(response).to have_http_status(:ok)
      end
    end
  end

  context 'with a not found response' do
    it 'returns a 404 and logs an info level message' do
      VCR.use_cassette('appeals/not_found') do
        get appeals_endpoint,
            params: nil,
            headers: { 'X-VA-SSN' => '111223333',
                       'X-Consumer-Username' => 'TestConsumer',
                       'X-VA-User' => 'adhoc.test.user' }
        expect(response).to have_http_status(:not_found)
        expect(response).to match_response_schema('errors')
      end
    end
  end
end
