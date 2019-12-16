# frozen_string_literal: true

require 'rails_helper'

def type_of_response(response)
  JSON.parse(response.body)['data'][0]['type']
end

RSpec.describe V0::FormsController, type: :controller do
  context 'with query param' do
    it 'returns forms' do
      VCR.use_cassette('forms/200_form_query') do
        get :index, params: { query: 'health' }
        expect(type_of_response(response)).to eq('va_form')
      end
    end
  end

  context 'without query param' do
    it 'returns forms' do
      VCR.use_cassette('forms/200_all_forms') do
        get :index
        expect(type_of_response(response)).to eq('va_form')
      end
    end
  end
end
