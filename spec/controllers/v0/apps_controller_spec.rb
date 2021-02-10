# frozen_string_literal: true

require 'rails_helper'

def type_of_response(response)
  JSON.parse(response.body)['data'][0]['type']
end

RSpec.describe V0::AppsController, type: :controller do
  context 'without query param' do
    it 'returns apps' do
      VCR.use_cassette('apps/200_all_apps') do
        get :index, params: nil
        expect(response.body).not_to be_empty
      end
    end
  end

  context 'with query param' do
    it 'returns a single app' do
      VCR.use_cassette('apps/200_app_query') do
        get :show, params: { id: 'iBlueButton' }
        expect(response.body).not_to be_empty
      end
    end
  end
end
