# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::LegacyAppeals::V2::LegacyAppealsController, type: :request do
  let(:path) { '/services/appeals/legacy_appeals/v2/schemas/headers' }

  it 'renders the json schema for request headers' do
    get path
    expect(response.status).to eq(200)

    json_body = JSON.parse response.body
    expect(json_body['description']).to eq('JSON Schema for Legacy Appeals endpoint headers (Decision Reviews API)')
  end
end
