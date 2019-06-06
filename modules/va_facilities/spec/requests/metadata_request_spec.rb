# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Facilities Metadata Endpoint', type: :request do
  describe '#get /docs/metadata' do
    it 'should return metadata JSON' do
      get '/services/va_facilities/docs/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
