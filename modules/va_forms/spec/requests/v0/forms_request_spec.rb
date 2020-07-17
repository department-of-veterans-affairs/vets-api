# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VA Forms', type: :request do
  include SchemaMatchers

  let!(:form) { FactoryBot.create(:va_form) }
  let(:base_url) { '/services/va_forms/v0/forms' }

  describe 'GET :index' do
    context 'with the camel inflection header' do
      let(:headers) do
        {
          'ACCEPT' => 'application/json',
          'CONTENT_TYPE' => 'application/json',
          'HTTP_X_KEY_INFLECTION' => 'camel'
        }
      end

      it 'returns the forms' do
        get base_url, headers: headers
        json = JSON.parse(response.body)

        expect(json.keys.count).to be 1
        expect(json).to have_key('data')
        expect(json['data'].size).to be 1
        expect(json['data'][0]).to have_key 'type'
        expect(json['data'][0]).to have_key 'id'
        expect(json['data'][0]).to have_key 'attributes'
        expect(json['data'][0]['attributes'].size).to be 8
        expect(json['data'][0]['attributes']).to have_key 'formName'
        expect(json['data'][0]['attributes']).to have_key 'url'
        expect(json['data'][0]['attributes']).to have_key 'title'
        expect(json['data'][0]['attributes']).to have_key 'firstIssuedOn'
        expect(json['data'][0]['attributes']).to have_key 'lastRevisionOn'
        expect(json['data'][0]['attributes']).to have_key 'pages'
        expect(json['data'][0]['attributes']).to have_key 'sha256'
        expect(json['data'][0]['attributes']).to have_key 'validPdf'
        expect(json['data'][0]['type']).to eq 'va_form'
      end
    end

    it 'returns the forms' do
      get base_url
      expect(response).to match_response_schema('va_forms/forms')
    end

    it 'correctly returns a matched query' do
      get "#{base_url}?query=526"
      expect(response).to match_response_schema('va_forms/forms')
    end

    it 'correctly returns a matched query while ignoring leading and trailing whitespace' do
      get "#{base_url}?query=%20526%20"
      expect(response).to match_response_schema('va_forms/forms')
    end

    it 'correctly returns a matched query using keywords separated by whitespace' do
      get "#{base_url}?query=disability%20form"
      expect(response).to match_response_schema('va_forms/forms')
    end
  end

  describe 'GET :show' do
    it 'returns the forms' do
      get "#{base_url}/#{form.form_name}"
      expect(response).to match_response_schema('va_forms/form')
    end
  end
end
