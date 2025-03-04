# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appeals Documentation Endpoints', type: :request do
  # @param [Hash] opts
  # @option opts [String] :path - Path to openapi docs
  # @option opts [String] :path_template - Path template to expect in generated docs where not standards-compliant
  shared_examples 'an openapi endpoint' do |opts|
    let(:path) { opts.fetch(:path) }

    it "successfully fetches openapi spec from #{opts[:path]}" do
      %w[sandbox production].each do |env|
        with_settings(Settings, vsp_environment: env) do
          get path
          status = response.status
          expect(response).to have_http_status(:ok), "Invalid HTTP status (#{status}) from #{path} on #{env}"

          json = JSON.parse(response.body)
          openapi_version = opts.fetch(:"openapi_version_#{env}", '3.0.0')
          expect(json['openapi']).to eq(openapi_version), "Invalid openapi version (#{json['openapi']}) on #{env}"
        end
      end
    end

    context 'servers' do
      let(:expected_path_template) { opts[:path_template] || path.gsub(/v\d.*$/, '{version}') }

      it 'lists the url formats for the sandbox & production environments' do
        get path
        json = JSON.parse response.body
        server_urls = json.fetch('servers').pluck('url')

        expect(server_urls).to include("https://sandbox-api.va.gov#{expected_path_template}")
        expect(server_urls).to include("https://api.va.gov#{expected_path_template}")
      end
    end
  end

  describe 'Appeals Status' do
    it_behaves_like 'an openapi endpoint',
                    path: '/services/appeals/docs/v0/api',
                    path_template: '/services/appeals/{version}'
    it_behaves_like 'an openapi endpoint', path: '/services/appeals/appeals-status/v1/docs'
  end

  describe 'Decision Reviews' do
    it_behaves_like 'an openapi endpoint',
                    path: '/services/appeals/docs/v1/decision_reviews',
                    path_template: '/services/appeals/{version}/decision_reviews'
    it_behaves_like 'an openapi endpoint',
                    path: '/services/appeals/v2/decision_reviews/docs',
                    path_template: '/services/appeals/{version}/decision_reviews'
  end

  describe 'Segmented APIs' do
    it_behaves_like 'an openapi endpoint', path: '/services/appeals/higher-level-reviews/v0/docs'
    it_behaves_like 'an openapi endpoint', path: '/services/appeals/notice-of-disagreements/v0/docs'
    it_behaves_like 'an openapi endpoint', path: '/services/appeals/supplemental-claims/v0/docs'
    it_behaves_like 'an openapi endpoint', path: '/services/appeals/appealable-issues/v0/docs'
    it_behaves_like 'an openapi endpoint', path: '/services/appeals/legacy-appeals/v0/docs'
  end
end
