# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VA Forms', type: :request do
  include SchemaMatchers

  let!(:form) { FactoryBot.create(:va_form) }
  let(:base_url) { '/services/va_forms/v0/forms' }

  describe 'GET :index' do
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
      get "#{base_url}?query=health%20care"
      data = JSON.parse(response.body)['data']
      expect(data.count).to eq(1)
      expect(data[0].id).to eq('10-10EZ (pdf)')
    end
  end

  describe 'GET :show' do
    it 'returns the forms' do
      get "#{base_url}/#{form.form_name}"
      expect(response).to match_response_schema('va_forms/form')
    end
  end
end
