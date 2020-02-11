# frozen_string_literal: true

require 'rails_helper'

describe 'forms', type: :request do
  include SchemaMatchers

  describe 'GET /v0/forms' do
    context 'with a query' do
      it 'matches the forms schema', :aggregate_failures do
        VCR.use_cassette('forms/200_form_query') do
          get '/v0/forms', params: { term: 'health' }

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('forms')
        end
      end
    end

    context 'without a query' do
      it 'matches the forms schema', :aggregate_failures do
        VCR.use_cassette('forms/200_all_forms') do
          get '/v0/forms'

          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('forms')
        end
      end
    end
  end
end
