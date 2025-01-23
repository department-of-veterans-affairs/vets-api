# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe 'Claim Appeals API endpoint', type: :request do
  context 'when requesting the healthcheck route' do
    it 'returns a successful response' do
      VCR.use_cassette('caseflow/health-check') do
        get '/services/appeals/v0/healthcheck'
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
