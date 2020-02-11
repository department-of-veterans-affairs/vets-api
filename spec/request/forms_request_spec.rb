# frozen_string_literal: true

require 'rails_helper'

def type_of_response(response)
  JSON.parse(response.body)['data'][0]['type']
end

describe 'forms', type: :request do
  include SchemaMatchers

  describe 'GET /v0/forms' do
    context 'with a query' do
      it 'matches the forms schema' do
        VCR.use_cassette('forms/200_form_query') do
          get '/v0/forms', params: { term: 'health' }

          expect(response).to have_http_status(:ok)
          expect(type_of_response(response)).to eq('va_form')
        end
      end
    end

    context 'without a query' do
      it 'matches the forms schema' do
        VCR.use_cassette('forms/200_all_forms') do
          get '/v0/forms'

          expect(response).to have_http_status(:ok)
          expect(type_of_response(response)).to eq('va_form')
        end
      end
    end
  end
end
