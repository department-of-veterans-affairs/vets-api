# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VA Forms', type: :request do
  include SchemaMatchers

  let!(:form) do
    create(:va_form)
    create(:va_form, form_name: '527', row_id: '4157')
    create(:deleted_va_form)
  end
  let(:base_url) { '/services/va_forms/v0/forms' }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  describe 'GET :index' do
    it 'returns the forms, including those that have been deleted' do
      get base_url
      data = JSON.parse(response.body)['data']
      expect(JSON.parse(response.body)['data'].length).to eq(3)
      expect(data[1]['attributes']['deleted_at']).to be_nil
      expect(data[2]['attributes']['deleted_at']).to be_truthy
      expect(response).to match_response_schema('va_forms/forms')
    end

    it 'returns the forms when camel-inflected' do
      get base_url, headers: inflection_header
      expect(response).to match_camelized_response_schema('va_forms/forms')
    end

    it 'correctly returns a matched query' do
      get "#{base_url}?query=526"
      expect(response).to match_response_schema('va_forms/forms')
    end

    it 'correctly returns a matched query when camel-inlfected' do
      get "#{base_url}?query=526", headers: inflection_header
      expect(response).to match_camelized_response_schema('va_forms/forms')
    end

    it 'correctly returns a matched query while ignoring leading and trailing whitespace' do
      get "#{base_url}?query=%20526%20"
      expect(response).to match_response_schema('va_forms/forms')
    end

    it 'correctly returns a matched query while ignoring leading and trailing whitespace when camel-inflected' do
      get "#{base_url}?query=%20526%20", headers: inflection_header
      expect(response).to match_camelized_response_schema('va_forms/forms')
    end

    it 'correctly returns a matched query using keywords separated by whitespace' do
      get "#{base_url}?query=disability%20form"
      expect(response).to match_response_schema('va_forms/forms')
    end

    it 'correctly returns a matched query using keywords separated by whitespace when camel-inflected' do
      get "#{base_url}?query=disability%20form", headers: inflection_header
      expect(response).to match_camelized_response_schema('va_forms/forms')
    end
  end

  describe 'GET :show' do
    it 'returns the forms' do
      get "#{base_url}/#{form.form_name}"
      expect(response).to match_response_schema('va_forms/form')
    end

    it 'returns the forms when camel-inflected' do
      get "#{base_url}/#{form.form_name}", headers: inflection_header
      expect(response).to match_camelized_response_schema('va_forms/form')
    end
  end
end
