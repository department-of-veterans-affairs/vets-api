# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::ApidocsController', type: :request do
  let(:openapi_version) { %w[openapi 3.0.0] }

  describe 'GET `index`' do
    it 'is successful' do
      get '/check_in/v2/apidocs'

      expect(response.status).to eq(200)
    end

    it 'is a hash' do
      get '/check_in/v2/apidocs'

      expect(JSON.parse(response.body)).to be_a(Hash)
    end

    it 'has the correct openapi version' do
      get '/check_in/v2/apidocs'

      expect(JSON.parse(response.body).first).to eq(openapi_version)
    end
  end
end
