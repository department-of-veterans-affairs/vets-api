# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::SupplementalClaims::V2::SupplementalClaimsController, type: :request do
  describe '#schema' do
    let(:path) { '/services/appeals/supplemental_claims/v2/schemas/200995' }

    it 'renders the json schema' do
      get path
      expect(response.status).to eq(200)

      json_body = JSON.parse response.body
      expect(json_body['description']).to eq('JSON Schema for VA Form 20-0995')
    end
  end
end
