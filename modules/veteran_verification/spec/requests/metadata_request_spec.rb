# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON for address validation' do
      get '/services/veteran_verification/address_validation_metadata'
      expect(response).to have_http_status(:ok)
      expect { JSON.parse(response.body) }.not_to raise_error
    end
  end
end
