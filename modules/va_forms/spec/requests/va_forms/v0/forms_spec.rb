# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAForms::V0::Forms', type: :request do
  include SchemaMatchers

  let!(:form) do
    create(:va_form)
    create(:va_form, form_name: '527', row_id: '4157')
    create(:deleted_va_form)
    create(:va_form, form_name: '21-2001', row_id: '4158')
  end
  let(:base_url) { '/services/va_forms/v0/forms' }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  describe 'GET :index' do
    it 'returns the forms, including those that were deleted' do
      get base_url
      data = JSON.parse(response.body)['data']
      expect(JSON.parse(response.body)['data'].length).to eq(4)
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

    it 'correctly returns a matched query when camel-inflected' do
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

    it 'correctly searches on word root' do
      result = VAForms::Form.search('Disabilities')
      expect(result.first.title).to eq(form.title)
    end

    it 'returns all forms when asked' do
      expect(VAForms::Form.return_all.count).to eq(4)
    end

    it 'correctly passes the regex test for Form Number 21-XXXX' do
      expect(VAForms::Form).to receive(:search_by_form_number).with('21-2001')
      get "#{base_url}?query=21-2001"
    end

    it 'returns the date of the last sha256 change' do
      get "#{base_url}?query=527"
      last_sha256_change = JSON.parse(response.body)['data'][0]['attributes']['last_sha256_change']
      expect(last_sha256_change).to eql(form.last_sha256_change.strftime('%Y-%m-%d'))
    end
  end

  describe 'GET :show' do
    it 'returns the form' do
      get "#{base_url}/#{form.form_name}"
      expect(response).to match_response_schema('va_forms/form')
    end

    it 'has a created date' do
      get "#{base_url}/#{form.form_name}"
      data = JSON.parse(response.body)['data']
      expect(data['attributes']['created_at']).to be_truthy
    end

    it 'returns a 404 when a form is not there' do
      get "#{base_url}/bad"
      expect(response).to have_http_status(:not_found)
    end

    it 'returns the forms when camel-inflected' do
      get "#{base_url}/#{form.form_name}", headers: inflection_header
      expect(response).to match_camelized_response_schema('va_forms/form')
    end

    it 'returns the form version history' do
      get "#{base_url}/#{form.form_name}"
      versions = JSON.parse(response.body)['data']['attributes']['versions']
      expect(versions).to eql(form.change_history['versions'])
    end
  end
end
