# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::LegacyAppeals::V0::LegacyAppealsController, type: :request do
  describe('#schema') do
    let(:path) { '/services/appeals/legacy_appeals/v0/schemas/headers' }

    it 'renders the json schema for request headers with shared refs' do
      with_openid_auth(described_class::OAUTH_SCOPES[:GET]) do |auth_header|
        get(path, headers: auth_header)
      end

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['description']).to eq(
        'JSON Schema for Legacy Appeals endpoint headers (Decision Reviews API)'
      )
      expect(response.body).to include('{"$ref":"non_blank_string.json"}')
    end

    it_behaves_like('an endpoint with OpenID auth', described_class::OAUTH_SCOPES[:GET]) do
      def make_request(auth_header)
        get(path, headers: auth_header)
      end
    end
  end
end
