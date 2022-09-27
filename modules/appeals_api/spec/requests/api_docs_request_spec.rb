# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appeals Documentation Endpoints', type: :request do
  # @param [Hash] opts
  # @option opts [String] :api_version The version of the OAS documentation to return. Required.
  # @option opts [Hash] :doc_path The suffix path to retrieve the OAS json from. Required.
  # @option opts [String] :server_path The OAS server suffix path. Required.
  # @option opts [Datetime] :openapi_version The openapi version to test with. Optional. Default is "3.0.0".
  shared_examples 'an openapi endpoint' do |opts|
    let(:doc_url) { "/services/appeals/docs/#{opts.fetch(:api_version)}/#{opts.fetch(:doc_path)}" }

    it "successfully returns openapi spec for #{opts.fetch(:api_version)}" do
      %w[sandbox production].each do |env|
        with_settings(Settings, vsp_environment: env) do
          spec_failure_msg = "Failed with #{doc_url} on #{env}"
          get doc_url
          expect(response).to have_http_status(:ok), spec_failure_msg
          json = JSON.parse(response.body)
          expect(json['openapi']).to eq(opts.fetch(:openapi_version, '3.0.0')), spec_failure_msg
        end
      end
    end

    context 'servers' do
      it 'lists the sandbox & production environments' do
        get doc_url
        json = JSON.parse response.body
        server_urls = json.fetch('servers').map { |server| server['url'] }
        expect(server_urls).to include("https://sandbox-api.va.gov/services/appeals/#{opts.fetch(:server_path)}")
        expect(server_urls).to include("https://api.va.gov/services/appeals/#{opts.fetch(:server_path)}")
      end
    end
  end

  describe 'Appeals Status' do
    it_behaves_like 'an openapi endpoint', api_version: 'v0', doc_path: 'api', server_path: '{version}'
  end

  describe 'Decision Reviews' do
    it_behaves_like 'an openapi endpoint', api_version: 'v1', doc_path: 'decision_reviews',
                                           server_path: '{version}/decision_reviews'
    it_behaves_like 'an openapi endpoint', api_version: 'v2', doc_path: 'decision_reviews',
                                           server_path: '{version}/decision_reviews'
  end

  describe 'Segmented APIs' do
    it_behaves_like 'an openapi endpoint', api_version: 'v2', doc_path: 'hlr',
                                           server_path: 'higher_level_reviews/{version}'
    it_behaves_like 'an openapi endpoint', api_version: 'v2', doc_path: 'nod',
                                           server_path: 'notice_of_disagreements/{version}'
    it_behaves_like 'an openapi endpoint', api_version: 'v2', doc_path: 'sc',
                                           server_path: 'supplemental_claims/{version}'
    it_behaves_like 'an openapi endpoint', api_version: 'v2', doc_path: 'ci',
                                           server_path: 'contestable_issues/{version}'
    it_behaves_like 'an openapi endpoint', api_version: 'v2', doc_path: 'la', server_path: 'legacy_appeals/{version}'
  end
end
