# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'
require Rails.root.join('modules', 'claims_api', 'spec', 'rails_helper.rb')
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_spec_helpers.rb')

metadata = {
  openapi_spec: Rswag::TextHelpers.new.claims_api_docs,
  production: false,
  bgs: {
    service: 'manage_representative_service',
    action: 'read_poa_request'
  }
}

xdescribe 'PowerOfAttorney', metadata do
  path '/power-of-attorney-requests' do
    get 'Search for Power of Attorney requests.' do
      tags 'Power of Attorney'
      operationId 'searchPowerOfAttorneyRequests'
      security [
        { productionOauth: ['system/claim.read', 'system/system/claim.write'] },
        { sandboxOauth: ['system/claim.read', 'system/system/claim.write'] },
        { bearer_token: [] }
      ]
      produces 'application/json'
      description 'Faceted, paginated, and sorted search of Power of Attorney requests'

      let(:Authorization) { 'Bearer token' }
      let(:scopes) { %w[system/claim.read system/system/claim.write] }

      response '200', 'Search results' do
        schema JSON.parse(Rails.root.join(
          'spec', 'support', 'schemas',
          'claims_api', 'v2', 'power_of_attorney_requests',
          'index.json'
        ).read)

        before do |example|
          mock_ccg(scopes) do
            use_bgs_cassette('nonempty') do
              submit_request(example.metadata)
            end
          end
        end

        after do |example|
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
        end

        it do |example|
          assert_response_matches_metadata(example.metadata)
        end
      end
    end
  end
end
