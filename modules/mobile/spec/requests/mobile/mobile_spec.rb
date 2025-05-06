# frozen_string_literal: true

require_relative '../../support/helpers/rails_helper'
require_relative '../../support/helpers/committee_helper'

RSpec.describe 'Mobile', type: :request do
  include CommitteeHelper

  describe 'GET /mobile' do
    before { get '/mobile' }

    it 'matches expected schema' do
      assert_schema_conform(200)
    end

    it 'returns a welcome message and list of mobile endpoints' do
      attributes = response.parsed_body.dig('data', 'attributes')
      expect(attributes['message']).to eq('Welcome to the mobile API.')
      expect(attributes['endpoints']).to include('mobile/v0/appeal/:id', 'mobile/v0/appointments')
    end
  end
end
