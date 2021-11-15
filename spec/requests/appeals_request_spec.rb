# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appeals Status' do
  include SchemaMatchers

  appeals_endpoint = '/v0/appeals'
  hlr_endpoint = '/v0/higher_level_reviews'
  hlr_get_contestable_issues_endpoint = "#{hlr_endpoint}/contestable_issues"

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
        VCR.use_cassette('caseflow/appeals') do
          get appeals_endpoint
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'with a not authorized response' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('caseflow/not_authorized') do
          get appeals_endpoint
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a not found response' do
      it 'returns a 404 and logs an info level message' do
        VCR.use_cassette('caseflow/not_found') do
          get appeals_endpoint
          expect(response).to have_http_status(:not_found)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an unprocessible entity response' do
      it 'returns a 422 and logs an info level message' do
        VCR.use_cassette('caseflow/invalid_ssn') do
          get appeals_endpoint
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with a server error' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('caseflow/server_error') do
          get appeals_endpoint
          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end
      end
    end

    context 'with an invalid JSON body in the response' do
      it 'returns a 502 and logs an error level message' do
        VCR.use_cassette('caseflow/invalid_body') do
          get appeals_endpoint
          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end

    context 'with a null eta' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals_null_eta') do
          get appeals_endpoint
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    context 'with no alert details due_date' do
      it 'returns a successful response' do
        VCR.use_cassette('caseflow/appeals_no_alert_details_due_date') do
          get appeals_endpoint
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('appeals')
        end
      end
    end

    describe 'GET /contestable_issues' do
      let(:ssn_with_mockdata) { '212222112' }
      let(:user) { build(:user, :loa3, ssn: ssn_with_mockdata) }
      let(:benefit_type) { 'compensation' }

      it 'returns a valid response' do
        VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-200') do
          get "#{hlr_get_contestable_issues_endpoint}/#{benefit_type}"
          expect(response).to have_http_status(:ok)
          expect { JSON.parse(response.body) }.not_to raise_error
          expect(JSON.parse(response.body)).to be_a Hash
        end
      end

      context 'with invalid request' do
        let(:benefit_type) { 'apricot' }

        it 'returns an invalid response' do
          VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-422') do
            get "#{hlr_get_contestable_issues_endpoint}/#{benefit_type}"
            expect(response).to have_http_status(:unprocessable_entity)
            expect { JSON.parse(response.body) }.not_to raise_error
            expect(JSON.parse(response.body)).to be_a Hash
          end
        end
      end

      context 'with veteran not found' do
        before do
          allow_any_instance_of(User).to receive(:ssn).and_return('000000000')
        end

        it 'returns 404' do
          VCR.use_cassette('decision_review/HLR-GET-CONTESTABLE-ISSUES-RESPONSE-404') do
            get "#{hlr_get_contestable_issues_endpoint}/#{benefit_type}"
            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end

    describe 'GET /higher_level_reviews' do
      context 'with a valid higher review response' do
        it 'higher level review endpoint returns a successful response' do
          VCR.use_cassette('decision_review/HLR-SHOW-RESPONSE-200') do
            get "#{hlr_endpoint}/75f5735b-c41d-499c-8ae2-ab2740180254"
            expect(response).to have_http_status(:ok)
            expect { JSON.parse(response.body) }.not_to raise_error
            expect(JSON.parse(response.body)).to be_a Hash
          end
        end
      end

      context 'with a higher review response id that does not exist' do
        it 'returns a 404 error' do
          VCR.use_cassette('decision_review/HLR-SHOW-RESPONSE-404') do
            get "#{hlr_endpoint}/0"
            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end

    describe 'POST /higher_level_reviews' do
      context 'with an accepted response' do
        it 'higher level review endpoint returns a successful response' do
          VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-200') do
            request_body = VetsJsonSchema::EXAMPLES['HLR-CREATE-REQUEST-BODY']
            post hlr_endpoint, params: request_body.to_json
            expect(response).to have_http_status(:ok)
            expect { JSON.parse(response.body) }.not_to raise_error
            expect(JSON.parse(response.body)).to be_a Hash
          end
        end
      end

      context 'with a malformed request' do
        it 'higher level review endpoint returns a 400 error' do
          VCR.use_cassette('decision_review/HLR-CREATE-RESPONSE-422') do
            post hlr_endpoint
            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)['errors'][0]['detail']).to eq "The request body isn't a JSON object"
          end
        end
      end
    end
  end
end
