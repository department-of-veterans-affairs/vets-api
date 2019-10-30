# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VA Forms', type: :request do
  include SchemaMatchers

  let(:form) { FactoryBot.create(:va_form) }

  describe 'GET :index' do
    it 'returns the forms' do
      form
      get '/services/va_forms/v0/forms'
      expect(response).to match_response_schema('va_forms/forms')
    end
  end

  describe 'GET :show' do
    it 'returns the forms' do
      form
      get "/services/va_forms/v0/forms/#{form.form_name}"
      expect(response).to match_response_schema('va_forms/form')
    end
  end
end
