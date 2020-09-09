# frozen_string_literal: true

require 'rails_helper'
require 'json'
RSpec.describe 'VA Forms', type: :request do
  include SchemaMatchers

  let!(:form) do
    create(:va_form)
    create(:va_form, form_name: '527')
    create(:deleted_va_form)
  end
  let(:base_url) { '/services/va_forms/v0/forms' }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  describe 'GET :index' do
    it 'returns the forms' do
      get base_url
      expect(JSON.parse(response.body)['data'].length).to eq(2)
      expect(response).to match_response_schema('va_forms/forms')
    end

    it 'returns deleted forms when show_deleted param is true' do
      get "#{base_url}?show_deleted=true"
      data = JSON.parse(response.body)['data']
      expect(data.length).to eq(3)
      expect(data[2]['attributes']['deleted_at']).to be_truthy
      expect(response).to match_response_schema('va_forms/forms')
    end

    it 'returns the forms when camel-inflected' do
      get base_url, headers: inflection_header
      expect(response).to match_camelized_response_schema('va_forms/forms')
    end

    # it 'returns deleted forms when camel-inflected and show_deleted param is true' do
    #   get "#{base_url}?show_deleted=true", headers: inflection_header
    #   data = JSON.parse(response.body)['data']
    #   puts data
    #   expect(data.length).to eq(3)
    #   expect(data[2]['attributes']['deleted_at']).to be_truthy
    #   expect(response).to match_camelized_response_schema('va_forms/forms')
    # end

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
