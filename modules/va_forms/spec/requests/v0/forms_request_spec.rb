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

    it "correctly doesn't return results that don't match" do
      get "#{base_url}?query=123123123"
      expect(JSON.parse(response.body)['data'].count).to eq(0)
    end
  end

  describe 'GET :show' do
    it 'returns the forms' do
      get "#{base_url}/#{form.form_name}"
      expect(response).to match_response_schema('va_forms/form')
    end
  end
end
