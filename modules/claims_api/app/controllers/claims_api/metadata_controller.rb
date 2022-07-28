# frozen_string_literal: true

module ClaimsApi
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)

    V2_DOCS_ENABLED = Settings.claims_api.v2_docs.enabled

    def index
      metadata_output = {
        meta: {
          versions: []
        }
      }
      metadata_output[:meta][:versions].push(version_1_docs)
      if V2_DOCS_ENABLED
        metadata_output[:meta][:versions].each { |version| version[:status] = VERSION_STATUS[:previous] }
        metadata_output[:meta][:versions].push(version_2_docs)
      end
      render json: metadata_output
    end

    private

    def version_1_docs
      {
        version: '1.0.0',
        internal_only: false,
        status: VERSION_STATUS[:current],
        path: '/services/claims/docs/v1/api',
        healthcheck: '/services/claims/v1/healthcheck'
      }
    end

    def version_2_docs
      {
        version: '2.0.0',
        internal_only: false,
        status: VERSION_STATUS[:current],
        path: '/services/claims/docs/v2/api',
        healthcheck: '/services/claims/v2/healthcheck'
      }
    end
  end
end
