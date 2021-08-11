# frozen_string_literal: true

module VeteranVerification
  class MetadataController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action(:authenticate)

    def veteran_verification
      render json: {
        meta: {
          versions: veteran_verification_versions
        }
      }
    end

    def veteran_verification_versions
      [
        veteran_verification_v0,
        veteran_verification_v1
      ]
    end

    def veteran_verification_v0
      {
        version: '0.0.1',
        internal_only: false,
        status: VERSION_STATUS[:previous],
        path: '/services/veteran_verification/docs/v0/veteran_verification',
        healthcheck: '/services/veteran_verification/v0/health'
      }
    end

    def veteran_verification_v1
      {
        version: '1.0.0',
        internal_only: false,
        status: VERSION_STATUS[:current],
        path: '/services/veteran_verification/docs/v1/veteran_verification',
        healthcheck: '/services/veteran_verification/v1/health'
      }
    end
  end
end
