# frozen_string_literal: true

module VeteranVerification
  class MetadataController < ::ApplicationController
    skip_before_action(:authenticate)

    def address_validation_metadata
      render json: {
        meta: {
          versions: [
            {
              version: '2.0.0',
              internal_only: true,
              status: VERSION_STATUS[:current],
              path: '/services/address_validation/docs/v2/api'
            },
            {
              version: '1.0.0',
              internal_only: true,
              status: VERSION_STATUS[:previous],
              path: '/services/address_validation/docs/v1/api'
            }
          ]
        }
      }
    end
  end
end
