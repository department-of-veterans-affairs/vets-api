# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Claim Appeals API endpoint', type: :request do
  include SchemaMatchers

  uuid = '1234567890'

  context 'with an loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1) }

    before do
      sign_in_as(user)
    end

    it 'higher level review endpoint returns a forbidden error' do
      get "/services/appeals/v0/appeals/higher_level_reviews/#{uuid}"
      expect(response).to have_http_status(:forbidden)
    end

    it 'intake_statuses endpoint returns a forbidden error' do
      get "/services/appeals/v0/appeals/intake_statuses/#{uuid}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with an loa3 user' do
    let(:user) { FactoryBot.create(:user, :loa3, ssn: '700062010') }

    before do
      sign_in_as(user)
    end

    it 'higher level review endpoint returns a successful response' do
      VCR.use_cassette('decision_review/200_review') do
        get "/services/appeals/v0/appeals/higher_level_reviews/#{uuid}"
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('higher_level_review')
      end
    end

    it 'intake_statuses endpoint returns a successful response' do
      VCR.use_cassette('decision_review/200_intake_status') do
        get "/services/appeals/v0/appeals/intake_statuses/#{uuid}"
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('intake_status')
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
        get '/services/appeals/v0/appeals', params: nil, headers: user_headers
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('appeals')
      end
    end

    it 'logs details about the request' do
      VCR.use_cassette('appeals/appeals') do
        allow(Rails.logger).to receive(:info)
        get '/services/appeals/v0/appeals', params: nil, headers: user_headers

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
        get '/services/appeals/v0/appeals', params: nil, headers: user_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('appeals')
      end
    end

    it 'logs appropriately' do
      VCR.use_cassette('appeals/appeals_empty') do
        allow(Rails.logger).to receive(:info)
        get '/services/appeals/v0/appeals', params: nil, headers: user_headers

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
        get '/services/appeals/v0/appeals',
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
        get '/services/appeals/v0/appeals',
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
        get '/services/appeals/v0/appeals',
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
