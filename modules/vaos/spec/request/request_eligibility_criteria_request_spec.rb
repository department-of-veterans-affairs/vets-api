# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'request eligibility criteria', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1) }

    it 'returns a forbidden error' do
      get '/vaos/v0/request_eligibility_criteria'
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('You do not have access to online scheduling')
    end
  end

  context 'with a loa3 user' do
    let(:user) { build(:user, :vaos) }
    let(:size) { JSON.parse(response.body)['data'].size }

    context 'with one id' do
      it 'returns a 200 with the correct schema' do
        VCR.use_cassette('vaos/systems/get_request_eligibility_criteria_by_id', match_requests_on: %i[method uri]) do
          get '/vaos/v0/request_eligibility_criteria', params: { site_codes: '688' }
          expect(response).to have_http_status(:ok)
          expect(size).to eq(1)
          expect(response).to match_response_schema('vaos/request_eligibility_criteria', { strict: false })
        end
      end

      it 'returns a 200 with the correct camel-inflected schema' do
        VCR.use_cassette('vaos/systems/get_request_eligibility_criteria_by_id', match_requests_on: %i[method uri]) do
          get '/vaos/v0/request_eligibility_criteria', params: { site_codes: '688' }, headers: inflection_header
          expect(response).to have_http_status(:ok)
          expect(size).to eq(1)
          expect(response).to match_camelized_response_schema('vaos/request_eligibility_criteria', { strict: false })
        end
      end
    end

    context 'with multiple site_codes' do
      it 'returns a 200 with the correct schema' do
        VCR.use_cassette('vaos/systems/get_request_eligibility_criteria_by_site_codes',
                         match_requests_on: %i[method uri]) do
          get '/vaos/v0/request_eligibility_criteria', params: { site_codes: %w[442 534] }
          expect(response).to have_http_status(:ok)
          expect(size).to eq(2)
          expect(response).to match_response_schema('vaos/request_eligibility_criteria', { strict: false })
        end
      end

      it 'returns a 200 with the correct camel-inflected schema' do
        VCR.use_cassette('vaos/systems/get_request_eligibility_criteria_by_site_codes',
                         match_requests_on: %i[method uri]) do
          get '/vaos/v0/request_eligibility_criteria', params: { site_codes: %w[442 534] }, headers: inflection_header
          expect(response).to have_http_status(:ok)
          expect(size).to eq(2)
          expect(response).to match_camelized_response_schema('vaos/request_eligibility_criteria', { strict: false })
        end
      end
    end

    context 'with multiple parent_sites' do
      it 'returns a 200 with the correct schema' do
        VCR.use_cassette('vaos/systems/get_request_eligibility_criteria_by_parent_sites',
                         match_requests_on: %i[method uri]) do
          get '/vaos/v0/request_eligibility_criteria', params: { parent_sites: %w[983 984] }
          expect(response).to have_http_status(:ok)
          expect(size).to eq(5)
          expect(response).to match_response_schema('vaos/request_eligibility_criteria', { strict: false })
        end
      end

      it 'returns a 200 with the correct camel-inflected schema' do
        VCR.use_cassette('vaos/systems/get_request_eligibility_criteria_by_parent_sites',
                         match_requests_on: %i[method uri]) do
          get '/vaos/v0/request_eligibility_criteria',\
              params: { parent_sites: %w[983 984] },
              headers: inflection_header

          expect(response).to have_http_status(:ok)
          expect(size).to eq(5)
          expect(response).to match_camelized_response_schema('vaos/request_eligibility_criteria', { strict: false })
        end
      end
    end
  end
end
