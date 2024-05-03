# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::ApidocsController', type: :request do
  describe 'GET `index`' do
    it 'is successful' do
      get '/facilities_api/v2/apidocs'

      expect(response.status).to eq(200)
    end

    it 'is a hash' do
      get '/facilities_api/v2/apidocs'

      expect(JSON.parse(response.body)).to be_a(Hash)
    end

    it 'has the correct tag description' do
      description = 'VA facilities, locations, hours of operation, available services'

      get '/facilities_api/v2/apidocs'

      expect(JSON.parse(response.body).dig('tags')[0]['description']).to eq(description)
    end
  end
end
